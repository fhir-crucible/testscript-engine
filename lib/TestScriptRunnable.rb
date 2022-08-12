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
                    'delete' => :delete,
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
      client.send(*create_request((operation_create(fixture_id))))
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
      client.send(*create_request((operation_delete(fixture_id))))
    end
  end

  def handle_actions(actions, end_on_fail)
    actions.each do |action|
      result = begin # TODO: Remove MessageHandler result objects when result no longer used
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
    if script.fixture.length == 0 
      then FHIR.logger.info '[.load_fixtures] No fixture found'
      return
    end

    FHIR.logger.info 'Beginning loading fixtures.'    
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

  def execute_operation(op)
    unless op.instance_of?(FHIR::TestScript::Setup::Action::Operation) && op.valid?
      fail(:invalid_operation)
      reply = nil
      return false
    end

    FHIR.logger.info "[.execute_operation] " + op.description
    FHIR.logger.info "[.execute_operation] Destination: " + op.destination.to_s if op.destination != nil

    request = create_request(op)
    if request.nil?
      fail(:invalid_request, (op.label || "unlabeled"))
      reply = nil
      return false
    end

    # FHIR.logger.info "[.execute_operation] Request: " + request.to_s

    begin
      #binding.pry
      client.send(*request)
      
    rescue StandardError => e
      fail(:execute_operation_error, (op.label || 'unlabeled'), e.message ) # TODO: Switch to ERROR
      reply = nil
      return false
    end

    storage(op)
    pass(:pass_execute_operation, op.label || 'unlabeled')
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

  # The assertion to perform
  # + Rule: Only a single assertion SHALL be present within setup action assert element.
  # + Rule: Setup action assert SHALL contain either compareToSourceId and compareToSourceExpression, compareToSourceId and compareToSourcePath or neither.
  # + Rule: Setup action assert response and responseCode SHALL be empty when direction equals request
  def evaluate assertion
    return unless assertion

    return report.fail 'invalidAssert' unless assertion.is_a? FHIR::TestScript::Setup::Action::Assert

    assertTypes = ['compareToSourceExpression', 'compareToSourcePath', 'contentType', 'expression', 'headerField', 'minimumId', 'navigationLinks', 'path', 'requestMethod', 'requestURL', 'response', 'responseCode', 'resource', 'validateProfileId']

    begin
      rawType = assertion.to_hash.find { |k, v| assertTypes.include? k }
      assertType = rawType[0].split(/(?<=\p{Ll})(?=\p{Lu})|(?<=\p{Lu})(?=\p{Lu}\p{Ll})/).map(&:downcase).join('_')
      self.send(("assert_#{assertType}").to_sym, assertion)

    rescue AssertionException => e
      return assertion.warningOnly ? report.warning(e.message) : report.fail(e.message)
    rescue StandardError => e
      FHIR.logger.error "Unable to process assertion. Error: #{e.message}"
      report.error e.message
      return
    end
    report.pass
  end

  def extract_path(operation, request_type)
    # If "url" element is defined, then "targetId", "resource", and "params" elements will be ignored. 
    # Test engines would use whatever is specified in "url" without tampering with the string (beyond encoding the URL for HTTP). 
    # Test engines do have to look for placeholders (${}) and replace the variable placeholders with the variable values at runtime before sending the request.
    return replace_variables(operation.url) if operation.url

    # If "params" element is specified, then "targetId" element is ignored. 
    # For FHIR operations that require a resource (e.g. "read" and "vread" operations), the "resource" element must be specified when "params" element is specified. 
    if operation.params
      mime = "&_format=#{get_format(operation.contentType)}" if operation.contentType
      params = "#{replace_variables(operation.params)}#{mime}"
      search = '/_search' if request_type == :post
      "#{operation.resource}#{search}#{params}"
    # If "url" and "params" elements are absent, then the request url will be constructed from "targetId" fixture if present. 
    # For "read" operation, the resource and id values will be extracted from "targetId" fixture and used to construct the url.
    # For "vread" and "history" operations, the versionId value will also be used. 
    # Test engines would append whatever is specified for "params" to the URL after the resource type without tampering with the string (beyond encoding the URL for HTTP).
    # The "params" element does not correspond exactly to "search parameters". Nor is it the "path". 
    # It corresponds to the part of the URL that comes after the [type] (when "resource" element is specified); 
    # e.g. It corresponds to "/[id]/_history/[vid] {?_format=[mime-type]}" in the following operation: 
    # GET [base]/[type]/[id]/_history/[vid] {?_format=[mime-type]} 
    # Test engines do have to look for placeholders (${}) and replace the variable placeholders with the variable values at runtime before sending the request.
    elsif operation.targetId
      resource = response_map[operation.targetId]&.[](:body)
      return if (resource.nil? and SENDERS.include?(request_type))
      type = operation.resource
      type = FHIR.from_contents(resource).resourceType if type.nil? and resource
      return unless type
      id = id_map[operation.targetId]
      return "#{type}/#{id}" unless type.nil? || id.nil?
    # sourceId: the id of the fixture used as the body of a PUT or POST request
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
    headers['Content-Type'] = 'application/fhir+json' unless headers['Content-Type']

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
