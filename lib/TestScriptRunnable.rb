# frozen_string_literal: true
require 'pry-nav'
require 'jsonpath'
require 'fhir_client'
require_relative 'assertions'
require_relative './MessageHandler.rb'
require_relative './TestReportHandler.rb'

class TestScriptRunnable
  REQUEST_TYPES = { 'read' => :get, 
                    'create' => :post, 
                    'update' => :put, 
                    'delete' => :delete, 
                    'search' => :get,
                    'history' => :get  }.freeze

  attr_accessor :script, :last_reply

  # maps fixture ids to server ids
  def id_map
    @id_map ||= {}
  end 

  # maps operation.responseid to responses
  def response_map
    @response_map ||= {}
  end 

  def fixtures
    @fixtures ||= load_fixtures
  end 

  def report
    @report ||= TestReportHandler.setup(script) 
  end 

  def client client = nil
    @client = client if client
    @client ||= FHIR::Client.new('https://localhost:8080')
  end 

  def initialize script
    extend MessageHandler

    unless (script.is_a? FHIR::TestScript) && script.valid?
      FHIR.logger.error '[.initialize] Received invalid or non-TestScript resource.'
      raise ArgumentError
    end 

    self.script = script
  end 

  def load_fixtures
    script.fixture.each_with_object({}) do |fixture, hash|
      next warn 'noFixtureId' unless fixture.id
      next warn 'noFixtureResource' unless fixture.resource
      next warn 'badFixtureReference' unless resource = get_resource_from_ref(fixture.resource)

      hash[fixture.id] = resource
      type = resource.resourceType

      script.setup.action.unshift action_create(fixture.id, type) if fixture.autocreate
      script.teardown.action << action_delete(fixture.id, type) if fixture.autodelete
    end 
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

  def action_delete(sourceId, type)
    FHIR::TestScript::Setup::Action.new({
      operation: FHIR::TestScript::Setup::Action::Operation.new({
        sourceId: sourceId,
        resource: type,
        local_method: 'delete'
      })
    })
  end 

  def action_create(sourceId, type)
    FHIR::TestScript::Setup::Action.new({
      operation: FHIR::TestScript::Setup::Action::Operation.new({
        sourceId: sourceId,
        resource: type,
        local_method: 'delete'
      })
    })
  end 

  def run client = nil
    client client

    [script.setup, *script.test, script.teardown].each do |section|
      next unless section

      section.action.each do |action|
        execute(action.operation) || evaluate(action.try(:assert))
      end 
    end 

    report.finalize
  end 

  def execute op
    return unless op

    FHIR.logger.info "[.execute]: #{op.description}"

    catch :exit do
      throw :exit, report.fail('noClient') unless client
      throw :exit, report.fail('noRequestType') unless op.type&.code || op.local_method
      
      request_type = REQUEST_TYPES[op.local_method || op.type.code]
      throw :exit, report.skip('notImplemented') unless request_type

      path = extract_path(op, request_type)
      throw :exit, report.fail('unknownFailure') unless path

      body = extract_body(op, request_type)
      throw :exit, report.fail('unknownFailure') unless body

      headers = extract_headers(op)
      headers = client.fhir_headers headers

      request = [request_type, path, body, headers]
      request.compact!

      begin
        if op.type.code == 'history'
          reply = client.resource_instance_history(op.class, id_map[op.targetId])
        else
          reply = client.send *request
        end
      rescue StandardError => e
        log_error e.message
        report.error e.message
        throw :exit
      end

      store_response(request_type, op, reply)
      report.pass
    end 
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
      return if operation.resource.nil? && requires_type(operation)

      mime = "{&_format=#{FORMAT_MAP[operation.contentType]}}" if operation.contentType
      params = "#{replace_variables(operation.params)}#{mime}"
      search = '/_search' if request_type == :post
      "#{operation.resource}#{search}#{params}"
    elsif operation.targetId
      type = response_map[operation.targetId]&.resource&.resourceType
      id = id_map[operation.targetId]
      return "#{type}/#{id}" unless type.nil? || id.nil?
    elsif operation.sourceId
      fixtures[operation.sourceId]&.resourceType
    end
  end

  # Determines if the operation requires [type] as part of
  # its intended request url
  def requires_type(operation)
    !['search'].include?(operation.type.code)
  end

  def extract_body(operation, request_type)
    return unless SENDER_TYPES.include?(request_type)
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

  def store_response(request_type, op, reply)
    return unless reply

    begin
      reply.resource = FHIR.from_contents(reply.response[:body].to_s)
    rescue
      reply.resource = nil        
    end

    self.last_reply = reply
    id_map.delete(reply.id) if request_type == :delete

    if op.responseId
      response_map[op.responseId] = reply
      id_map[op.responseId] = reply.resource&.id if SENDER_TYPES.include?(request_type)
    elsif op.sourceId
      id_map[op.sourceId] = reply.resource&.id if SENDER_TYPES.include?(request_type)
    end 
  end

  def find_resource id
    fixtures[id] || response_map[id]&.response&.[](:body)
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
      headers = response_map[var.sourceId]&.response&.[](:headers)
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

  include Assertions

  SENDER_TYPES = %i[post put].freeze
  FETCHER_TYPES = %i[get delete search].freeze

  FORMAT_MAP = {
    'json' => FHIR::Formats::ResourceFormat::RESOURCE_JSON,
    'xml' => FHIR::Formats::ResourceFormat::RESOURCE_XML
  }.freeze
end
