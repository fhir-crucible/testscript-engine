# frozen_string_literal: true
require 'pry-nav'
require 'jsonpath'
require 'fhir_client'
require_relative 'assertions'
require_relative './TestReportHandler.rb'

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

  # def report
  #   @report ||= TestReportHandler.report(script)
  # end
  # Storing the report structure and a fresh stack of operations
  # Anytime this runnable is run, it creates a copy of those things and completes them
  # To confirm: if I have two instances of a class, and both classes include a module, where that
  # module itself includes a data structure, do the two instances share the same data structure?
    # possibly, matters whether the class is included or extended

  def autocreate_ids
    @autocreate_ids ||= []
  end

  def autodelete_ids
    @autocreate_ids ||= []
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

    setup_execution
    test_execution
    teardown_execution

    post_processing

    report.finalize
  end

  def pre_processing
    FHIR.logger.info 'Begin pre-processing.'
    load_fixtures

    autocreate_ids.each do |fixture_id|
      FHIR.logger.info "Auto-creating static fixture #{fixture_id}"
      execute_operation(operation_create(fixture_id))
    end

    FHIR.logger.info 'Finish pre-processing.'
  end

  def setup_execution
    return unless script.setup

    FHIR.logger.info 'Begin setup.'

    handle_actions(script.setup.action, true)

    FHIR.logger.info 'Finish setup.'
  end

  def test_execution
    return if script.test.empty?

    FHIR.logger.info 'Begin test execution.'

    script.test.each { |test| handle_actions(test.action, false) }

    FHIR.logger.info 'Finish test execution.'
  end

  def teardown_execution
    return unless script.teardown

    FHIR.logger.info 'Begin teardown.'

    handle_actions(script.teardown.action, false)

    FHIR.logger.info 'Finish teardown.'
  end

  def post_processing
    FHIR.logger.info 'Begin post-processing.'

    autodelete_ids.each do |fixture_id|
      FHIR.logger.info "Auto-deleting dynamic fixture #{fixture_id}"
      execute_operation(operation_delete(fixture_id))
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

      if result == 'fail' and end_on_fail
        # TODO: Populate TestReport with fails
        return
      end
    end
  end

  def operation_create(sourceId)
    FHIR::TestScript::Setup::Action::Operation.new({
      sourceId: sourceId,
      local_method: 'create'
    })
  end

  def operation_delete(sourceId)
    FHIR::TestScript::Setup::Action::Operation.new({
      targetId: id_map[sourceId],
      local_method: 'delete'
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
      FHIR.logger.info '[.execute_operation] Can not execute invalid Operation.'
      return 'fail'
    end

    request = create_request(op)
    if request.nil?
      FHIR.logger.info "[.execute_operation] Unable to create a request, can not execute Operation #{op.label || '[unlabeled]'}."
      return 'fail'
    end

    begin
      client.send(*request)
    rescue StandardError => e
      FHIR.logger.info "[.execute_operation] ERROR: #{e.message} while executing Operation #{op.label || '[unlabeled]'}."
      return 'fail'
    end

    storage(op)
    'pass'
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

  def evaluate_path(path, resource)
    return unless path and resource

    begin
      # Then, try xpath if necessary
      result = extract_xpath_value(resource.to_xml, path)
    rescue
      # If xpath fails, see if JSON path will work...
      result = JsonPath.new(path).first(resource.to_json)
    end
    return result
  end

  def extract_xpath_value(resource_xml, resource_xpath)
    # Massage the xpath if it doesn't have fhir: namespace or if doesn't end in @value
    # Also make it look in the entire xml document instead of just starting at the root
    xpath = resource_xpath.split('/').map do |s|
      s.starts_with?('fhir:') || s.length.zero? || s.starts_with?('@') ? s : "fhir:#{s}"
    end.join('/')
    xpath = "#{xpath}/@value" unless xpath.ends_with? '@value'
    xpath = "//#{xpath}"

    resource_doc = Nokogiri::XML(resource_xml)
    resource_doc.root.add_namespace_definition('fhir', 'http://hl7.org/fhir')
    resource_element = resource_doc.xpath(xpath)

    # This doesn't work on warningOnly; consider putting back in place
    # raise AssertionException.new("[#{resource_xpath}] resolved to multiple values instead of a single value", resource_element.to_s) if resource_element.length>1
    resource_element.first.try(:value)
  end

  # <--- Line of Code Review --->

  SENDERS = %i[post put].freeze
  FETCHERS = %i[get destroy search].freeze

  FORMAT_MAP = {
    'json' => FHIR::Formats::ResourceFormat::RESOURCE_JSON,
    'xml' => FHIR::Formats::ResourceFormat::RESOURCE_XML
  }.freeze
end
