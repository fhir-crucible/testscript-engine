# frozen_string_literal: true
require 'pry-nav'
require 'jsonpath'
require 'fhir_client'
require_relative 'assertions'
require_relative './TestReportHandler.rb'
require_relative './MessageHandler.rb'
require_relative './Operation.rb'

class TestScriptRunnable
  include Assertions
  prepend MessageHandler
  include TestReportHandler
  include Operation

  attr_accessor :reply

  # maps fixture ids to server ids
  def id_map
    @id_map ||= {}
  end

  # maps operation.responseid to responses
  def response_map
    @response_map ||= {}
  end

  def request_map
    @request_map ||= {}
  end

  def fixtures
    @fixtures ||= {}
  end

  def autocreate_ids
    @autocreate_ids ||= []
  end

  def autodelete_ids
    @autodelete_ids ||= []
  end

  def script(script = nil)
    @script = script if script
    @script
  end

  def client(client = nil)
    @client = client if client
    @client ||= FHIR::Client.new('https://localhost:8080')
  end

  def initialize script
    unless (script.is_a? FHIR::TestScript) && script.valid?
      fail(:invalid_script) # TODO: Switch to ERROR
      raise ArgumentError
    end

    script(script)

    # TODO - move preprocessing to the 'run' method
    # I'll do this in a follow-up PR. The reason is that preprocessing,
    # since it includes autoloading fixtures, can't be done only one. It
    # needs to be done each time the script is executed i.e. autloading
    # for any system under test.
    #
    # For now, just move the call to preprocessing to the run method to
    # see how the output will look under regular conditions
    #
    # preprocessing
  end

  def run(client = nil)
    client(client)
    fresh_testreport

    preprocessing # TODO: remove this

    setup if script.setup
    test unless script.test.empty?
    teardown if script.teardown

    postprocessing

    finalize_report
  end

  def preprocessing
    load_fixtures

    autocreate_ids.each do |fixture_id|
      client.send(*build_request((operation_create(fixture_id))))
    end
  end

  def setup
    handle_actions(script.setup.action, true)
  end

  def test
    script.test.each { |test| handle_actions(test.action, false) }
  end

  def teardown
    handle_actions(script.teardown.action, false)
  end

  def postprocessing

    autodelete_ids.each do |fixture_id|
      FHIR.logger.info "Auto-deleting dynamic fixture #{fixture_id}"
      client.send(*build_request((operation_delete(fixture_id))))
    end
  end

  def handle_actions(actions, end_on_fail)
    actions.each do |action|
      result = begin # TODO: Remove MessageHandler result objects when result no longer used
        if action.operation
          execute(action.operation)
        elsif action.respond_to?(:assert)
          evaluate(action.assert)
        end
      end

      if result == false and end_on_fail
        # TODO: Implement some flow control for ending execution
        # Already support in report handler -- cascade_skips attr_accessor
      end
    end
  end

  def load_fixtures
    script.fixture.each do |fixture|
      info(:no_static_fixture_id) unless fixture.id
      info(:no_static_fixture_resource) unless fixture.resource

      resource = get_resource_from_ref(fixture.resource)
      info(:no_static_fixture_reference) unless resource

      info(:loaded_static_fixture, fixture.id)
      fixtures[fixture.id] = resource
      type = resource.resourceType

      autocreate_ids << fixture.id if fixture.autocreate
      autodelete_ids << fixture.id if fixture.autodelete
    end
  end

  def get_resource_from_ref reference
    return unless reference.is_a? FHIR::Reference
    return unless ref = reference.reference

    return warning(:unsupported_ref, ref) if ref.start_with? 'http'
    return script.contained.find { |r| r.id == ref[1..] } if ref.start_with? '#'

    begin
      fixtures_path = script.url.split('/')[0...-1].join('/') + '/fixtures'
      filepath = File.expand_path(ref, File.absolute_path(fixtures_path))
      file = File.open(filepath, 'r:UTF-8', &:read)
      file.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
      return FHIR.from_contents(file)
    rescue StandardError => e
      warning(:bad_reference, ref) # TODO: Switch to ERROR? Or not?
    end
  end

  def storage(op)
    self.reply = client.reply
    reply.nil? ? return : client.reply = nil

    request_map[op.requestId] = reply.request if op.requestId
    response_map[op.responseId] = reply.response if op.responseId

    (reply.resource = FHIR.from_contents(reply.response&.[](:body).to_s)) rescue {}
    (reply.response[:body] = reply.resource)
    response_map[op.responseId][:body] = reply.resource if reply.resource and response_map[op.responseId]

    if op.targetId and (reply.request[:method] == :delete) and ['200', '201', '204'].include?(reply.response[:code])
      id_map.delete(op.targetId) and return
    end

    dynamic_id = reply.resource&.id || begin
      reply.response&.[](:headers)&.[]('location')&.remove(reply.request[:url].to_s)&.split('/')&.[](2)
    end

    id_map[op.responseId] = dynamic_id if op.responseId and dynamic_id
    id_map[op.sourceId] = dynamic_id if op.sourceId and dynamic_id
    return
  end

  def find_resource id
    fixtures[id] || response_map[id]&.[](:body)
  end

  def replace_variables placeholder
    return placeholder unless placeholder&.include? '${'
    replaced = placeholder.clone

    script.variable.each do |var|
      next unless replaced.include? "${#{var.name}}"
      replacement = evaluate_variable(var)
      replaced.gsub!("${#{var.name}}", replacement) if replacement
    end

    return replaced
  end

  def evaluate_variable var
    if var.expression
      evaluate_expression(var.expression, find_resource(var.sourceId))
    elsif var.path
      evaluate_path(var.path, find_resource(var.sourceId))
    elsif var.headerField
      headers = response_map[var.sourceId]&.[](:headers)
      headers&.find { |h, v| h == var.headerField.downcase }&.last
    end || var.defaultValue
  end

  def evaluate_expression(expression, resource)
    return unless expression and resource

    return FHIRPath.evaluate(expression, resource.to_hash)
  end
end
