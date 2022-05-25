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

  def id_map
    @id_map ||= {}
  end 

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
      
      # Need to consider where to put this code, such as a separate method before setup execition.
      if fixture.autocreate
        FHIR.logger.info "[.load_fixture] Autocreate Fixture: #{fixture.id}"
        script.setup.action.each do |ac|
            next if ac.operation == nil
            if ac.operation.sourceId == fixture.id
              FHIR.logger.warn "Possible duplication of fixture creation (autocreation and setup section)"
              FHIR.logger.warn "Check setup in TestScript. Operation type: #{ac.operation.type.code} , sourceId: #{ac.operation.sourceId}"
            end
        end

        begin
          client.create(get_resource_from_ref(fixture.resource))
        rescue StandardError => e
          log_error e.message
          report.error e.message
          throw :exit
        end
      end
 
      # script.setup.action.unshift action_create(fixture.id, type) if fixture.autocreate
      # script.teardown.action << action_delete(fixture.id, type) if fixture.autodelete
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

  # Failure of postprocessing (autodelete) won't fail test as opposed to failure of autocreate will.
  def postprocess 
    script.fixture.each_with_object({}) do |fixture|
      if fixture.autodelete
        FHIR.logger.info "[.load_fixture] Autodelete Fixture: #{fixture.id}"
        resource = get_resource_from_ref(fixture.resource)
        reply = client.destroy(resource.class, resource.id)
      end
    end
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

    FHIR.logger.info "[.execute] #{op.description}"

    catch :exit do
      throw :exit, report.fail('noClient') unless client
      throw :exit, report.fail('noRequestType') unless op.type&.code || op.local_method
      
      request_type = REQUEST_TYPES[op.local_method || op.type.code]
      throw :exit, report.skip('notImplemented') unless request_type

      request = [request_type, extract_path(op), extract_body(request_type, op), extract_headers(op)]
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
  
  def extract_path op
    return replace_variables(op.url) if op.url
    pieces = { format: FORMAT_MAP[op.contentType] }

    if op.targetId
      pieces[:id] = id_map[op.targetId]
      pieces[:resource] = find_resource(op.targetId).resourceType

      throw :exit, report.fail('noId') unless pieces[:id]
      throw :exit, report.fail('noTargetIdFixture') unless pieces[:resource]
    elsif op.params
      pieces[:resource] = replace_variables op.resource
      pieces[:params] = replace_variables op.params

      throw :exit, report.fail('noResource') unless pieces[:resource]
    elsif op.sourceId
      pieces[:resource] = find_resource(op.sourceId).resourceType

      throw :exit, report.fail('noSourceFixture') unless fixtures[op.sourceId].resourceType
    end

    # TODO: requestEncodeUrl?
    client.resource_url(pieces)
  end

  def extract_body(request_type, op)
    return unless SENDER_TYPES.include?(request_type)

    body = find_resource(op.sourceId || op.targetId)
    throw :exit, report.fail('noSourceFixture') unless body
    return body
  end

  def extract_headers op
    requestHeaders = Hash[op.requestHeader.map { |h| [h.field, h.value] }]
    requestHeaders.merge!({ accept: FORMAT_MAP[op.accept] }) if op.accept
    requestHeaders.merge!({ content_type: FORMAT_MAP[op.contentType] }) if op.contentType
    client.fhir_headers requestHeaders
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

  def replace_variables input
    return input unless input&.include? '${'

    script.variable.each do |var|
      next unless input.include? "${#{var.name}}"
      val = nil

      if var.expression
        val = evaluate_expression(var.expression, find_resource(var.sourceId))
      elsif var.headerField
        headers = response_map[var.sourceId]&.response&.[](:headers)
        val = headers&.find { |h, v| h == var.headerField.downcase }&.last
      elsif var.path
        val = evaluate_path(var.path, find_resource(var.sourceId))
      end 

      val ||= var.defaultValue 
      input.gsub!("${#{var.name}}", val) if val
    end 

    return input # TODO: Add error control for unresolvable variable via input.include? '${'
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
    nil => FHIR::Formats::ResourceFormat::RESOURCE_JSON,
    'json' => FHIR::Formats::ResourceFormat::RESOURCE_JSON,
    'xml' => FHIR::Formats::ResourceFormat::RESOURCE_XML
  }.freeze
end
