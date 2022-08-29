# frozen_string_literal: true
require 'pry-nav'
require 'jsonpath'
require 'fhir_client'
require_relative 'assertions'
require_relative './TestReportHandler.rb'
require_relative './MessageHandler.rb'

class TestScriptRunnable
  include Assertions
  include TestReportHandler

  REQUEST_TYPES = { 'read' => :get,
                    'create' => :post,
                    'update' => :put,
                    'delete' => :destroy,
                    'search' => :get,
                    'history' => :get,
                    nil => :get }.freeze

  attr_accessor :reply

  prepend MessageHandler

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
      FHIR.logger.error '[.initialize] Received invalid or non-TestScript resource.'
      raise ArgumentError
    end

    script(script)

    pre_processing
  end

  def run(client = nil)
    client(client)
    fresh_testreport # Create a new testreport each time the runnable is executed

    setup if script.setup
    test unless script.test.empty?
    teardown if script.teardown

    post_processing

    finalize_report
  end

  def pre_processing
    FHIR.logger.info 'Begin pre-processing.'
    load_fixtures

    autocreate_ids.each do |fixture_id|
      FHIR.logger.info "Auto-creating static fixture #{fixture_id}"
      # Modified: Previously, called execute_operation
      # However, don't want everything that execute_operation does (storing response, updating test report etc.)
      # So, just simplify and do the sending here without all that extra stuff
      client.send(*create_request((operation_create(fixture_id))))
    end

    FHIR.logger.info 'Finish pre-processing.'
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

  def post_processing
    FHIR.logger.info 'Begin post-processing.'

    autodelete_ids.each do |fixture_id|
      FHIR.logger.info "Auto-deleting dynamic fixture #{fixture_id}"
      client.send(*create_request((operation_delete(fixture_id))))
    end

    FHIR.logger.info 'Finish post-processing.'
  end

  def handle_actions(actions, end_on_fail)
    actions.each do |action|
      result = begin
        if action.operation
          execute_operation(action.operation)
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

  def operation_create(sourceId)
    FHIR::TestScript::Setup::Action::Operation.new({
      sourceId: sourceId,
      method: 'post'
    })
  end

  def operation_delete(sourceId)
    FHIR::TestScript::Setup::Action::Operation.new({
      targetId: id_map[sourceId],
      method: 'delete'
    })
  end

  def load_fixtures
    FHIR.logger.info 'Beginning loading fixtures.'
    script.fixture.each do |fixture|
      FHIR.logger.info 'No ID for static fixture, can not process.' unless fixture.id
      FHIR.logger.info 'No resource for static fixture, can not process.' unless fixture.resource

      resource = get_resource_from_ref(fixture.resource)
      FHIR.logger.info 'No reference for static fixture, can not process' unless resource

      FHIR.logger.info "Storing static fixture #{fixture.id}"
      fixtures[fixture.id] = resource
      type = resource.resourceType

      autocreate_ids << fixture.id if fixture.autocreate
      autodelete_ids << fixture.id if fixture.autodelete
    end
    FHIR.logger.info 'Finishing loading fixtures.'
  end

  def get_resource_from_ref reference
    return unless reference.is_a? FHIR::Reference
    return unless ref = reference.reference

    return warn('unsupportedRef', ref) if ref.start_with? 'http'
    return script.contained.find { |r| r.id == ref[1..] } if ref.start_with? '#'

    begin
      fixtures_path = script.url.split('/')[0...-1].join('/') + '/fixtures'
      filepath = File.expand_path(ref, File.absolute_path(fixtures_path))
      file = File.open(filepath, 'r:UTF-8', &:read)
      file.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
      return FHIR.from_contents(file)
    rescue StandardError => e
      warn('badReference', ref)
    end
  end

  def execute_operation(op)
    unless op.instance_of?(FHIR::TestScript::Setup::Action::Operation) && op.valid?
      message = '[.execute_operation] Can not execute invalid Operation.'
      action_fail(:invalid_operation)
      fail(message)
      return false
    end

    request = create_request(op)
    if request.nil?
      message = "[.execute_operation] Unable to create a request, can not execute Operation #{op.label || '[unlabeled]'}."
      action_fail(:invalid_request)
      fail(message)
      return false
    end

    begin
      client.send(*request)
    rescue StandardError => e
      message = "[.execute_operation] ERROR: #{e.message} while executing Operation #{op.label || '[unlabeled]'}."
      action_error(:execution_error)
      fail(message)
      return false
    end

    storage(op)
    pass
    return true
  end

  def create_request(op)
    req_type = op.local_method&.to_sym || REQUEST_TYPES[op.type&.code]

    request = [req_type,
               extract_path(op, req_type),
               extract_body(op, req_type),
               client.fhir_headers(extract_headers(op))]

    return if SENDERS.include?(req_type) && request[2].nil?

    request.compact
  end

  def extract_path(operation, request_type)
    return replace_variables(operation.url) if operation.url

    if operation.params
      mime = "&_format=#{get_format(operation.contentType)}" if operation.contentType
      params = "#{replace_variables(operation.params)}#{mime}"
      search = '/_search' if request_type == :post
      "#{operation.resource}#{search}#{params}"
    elsif operation.targetId
      resource = response_map[operation.targetId]&.[](:body)
      return unless resource
      type = FHIR.from_contents(resource).resourceType
      id = id_map[operation.targetId]
      return "#{type}/#{id}" unless type.nil? || id.nil?
    elsif operation.sourceId
      (fixtures[operation.sourceId] || begin
        resource = response_map[operation.sourceId]&.[](:body)
        return unless resource
        FHIR.from_contents(resource)
      end).resourceType
    end
  end

  def extract_body(operation, request_type)
    return unless SENDERS.include?(request_type)
    return unless operation.sourceId || operation.targetId

    fixtures[operation.sourceId] or response_map[operation.targetId]&.resource
  end

  def extract_headers(operation)
    headers = {}
    headers.merge!({ 'Accept' => get_format(operation.accept) }) if operation.accept
    headers.merge!({ 'Content-Type' => get_format(operation.contentType) }) if operation.contentType

    headers.merge! Hash[operation.requestHeader.map do |header|
      [header.field, replace_variables(header.value)]
    end]

    headers.empty? ? nil : headers
  end

  def get_format format
    FORMAT_MAP[format] || format
  end

  def successful? code
    [200, 202, 204].include? code
  end

  def storage(op)
    self.reply = client.reply
    reply.nil? ? return : client.reply = nil

    request_map[op.requestId] = reply.request if op.requestId
    response_map[op.responseId] = reply.response if op.responseId

    (reply.resource = FHIR.from_contents(reply.response&.[](:body).to_s)) rescue {}
    (reply.response[:body] = reply.resource)
    response_map[op.responseId][:body] = reply.resource if reply.resource and response_map[op.responseId]

    if op.targetId and (reply.request[:method] == :delete) and successful?(reply.response[:code])
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

  # <--- Line of Code Review --->

  SENDERS = %i[post put].freeze
  FETCHERS = %i[get destroy search].freeze

  FORMAT_MAP = {
    'json' => FHIR::Formats::ResourceFormat::RESOURCE_JSON,
    'xml' => FHIR::Formats::ResourceFormat::RESOURCE_XML
  }.freeze
end
