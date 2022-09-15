# frozen_string_literal: true
require 'pry-nav'
require 'jsonpath'
require 'fhir_client'
require_relative 'operation'
require_relative 'assertion'
require_relative 'message_handler'
require_relative 'testreport_handler'

class TestScriptRunnable
  include Operation
  include Assertion
  prepend MessageHandler
  include TestReportHandler

  attr_accessor :script, :client, :reply

  def id_map
    @id_map ||= {}
  end

  def fixtures
    @fixtures ||= {}
  end

  def request_map
    @request_map ||= {}
  end

  def response_map
    @response_map ||= {}
  end

  def autocreate
    @autocreate ||= []
  end

  def autodelete_ids
    @autodelete_ids ||= []
  end

  def initialize(script)
    raise ArgumentError.new(messages(:bad_script)) unless script.is_a?(FHIR::TestScript)
    raise ArgumentError.new(messages(:invalid_script_input)) unless script.valid?

    @script = script
    load_fixtures
  end

  def run(client)
    @client = client

    fresh_testreport

    preprocess
    setup
    test
    teardown
    postprocessing

    finalize_report
  end

  def preprocess
    return info(:no_preprocess) if autocreate.empty?
    autocreate.each { |fixture| client.send(*build_request((create_operation(fixture)))) }
  end

  def setup
    return info(:no_setup) unless script.setup
    handle_actions(script.setup.action, true)
  end

  def test
    script.test.each { |test| handle_actions(test.action, false) }
  end

  def teardown
    return info(:no_teardown) unless script.teardown
    handle_actions(script.teardown.action, false)
  end

  def postprocessing
    return info(:no_postprocess) if autocreate.empty?

    autodelete_ids.each do |fixture_id|
      client.send(*build_request((delete_operation(fixture_id))))
    end

    @ended = nil
    @id_map = {}
    @request_map = {}
    @response_map = {}
  end

  def handle_actions(actions, end_on_fail)
    return abort_test(actions) if @ended
    @modify_report = true
    current_action = 0

    begin
      actions.each do |action|
        current_action += 1
        if action.operation
          execute(action.operation)
        elsif action.respond_to?(:assert)
          begin
            evaluate(action.assert)
          rescue AssertionException => ae
            if ae.outcome == :skip
              skip(:eval_assert_result, ae.details)
            elsif ae.outcome == :fail
              next warning(:eval_assert_result, ae.details) if action.assert.warningOnly
              if end_on_fail
                @ended = true
                fail(:eval_assert_result, ae.details)
                cascade_skips_with_message(actions, current_action) unless current_action == actions.length
                return
              else
                fail(:eval_assert_result, ae.details)
              end
            end
          end
        end
      end
    rescue OperationException => oe
      error(oe.details)
      cascade_skips_with_message(actions, current_action)
    rescue => e
      error(:uncaught_error, e.message)
      cascade_skips_with_message(actions, current_action)
    end

    @modify_report = false
  end

  def cascade_skips_with_message(actions, current_action)
    actions_to_skip = actions.slice(current_action, actions.length)
    cascade_skips(:skip_on_fail, actions_to_skip, actions_to_skip.length)
  end

  def abort_test(actions_to_skip)
    cascade_skips(:abort_test, actions_to_skip, 'setup', actions_to_skip.length)
  end

  def load_fixtures
    script.fixture.each do |fixture|
      next warning(:no_static_fixture_id) unless fixture.id
      next warning(:no_static_fixture_resource) unless fixture.resource

      resource = get_resource_from_ref(fixture.resource)
      next warning(:bad_static_fixture_reference) unless resource

      fixtures[fixture.id] = resource
      autocreate << fixture.id if fixture.autocreate
      autodelete_ids << fixture.id if fixture.autodelete
    end
  end

  def get_resource_from_ref(reference)
    return warning(:bad_reference) unless reference.is_a?(FHIR::Reference)

    ref = reference.reference
    return warning(:no_reference) unless ref
    return warning(:unsupported_ref, ref) if ref.start_with? 'http'

    if ref.start_with? '#'
      contained = script.contained.find { |r| r.id == ref[1..] }
      return contained || warning(:no_contained_resource, ref)
    end

    begin
      fixture_path = script.url.split('/')[0...-1].join('/') + '/fixtures'
      filepath = File.expand_path(ref, File.absolute_path(fixture_path))
      file = File.open(filepath, 'r:UTF-8', &:read)
      file.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
      resource = FHIR.from_contents(file)
      info(:loaded_static_fixture, ref, script.id)
      return resource
    rescue => e
      warning(:resource_extraction, ref, e.message)
    end
  end

  def storage(op)
    @reply = client.reply
    reply.nil? ? return : client.reply = nil

    request_map[op.requestId] = reply.request if op.requestId
    response_map[op.responseId] = reply.response if op.responseId

    (reply.resource = FHIR.from_contents(reply.response&.[](:body).to_s)) rescue {}
    (reply.response[:body] = reply.resource)
    response_map[op.responseId][:body] = reply.resource if reply.resource and response_map[op.responseId]

    if op.targetId and (reply.request[:method] == :delete) and [200, 201, 204].include?(reply.response[:code])
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
      headers&.find { |h, v| h == var.headerField || h == var.headerField.downcase }&.last
    end || var.defaultValue
  end

  def evaluate_expression(expression, resource)
    return unless expression and resource

    return FHIRPath.evaluate(expression, resource.to_hash)
  end
end
