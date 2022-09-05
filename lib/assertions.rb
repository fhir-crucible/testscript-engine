# frozen_string_literal: true
require 'pry-nav'
require 'jsonpath'
require 'active_support'

module Assertions

  ASSERT_TYPES_MATCHER = /(?<=\p{Ll})(?=\p{Lu})|(?<=\p{Lu})(?=\p{Lu}\p{Ll})/
  ASSERT_TYPES = [
    "contentType",
    "expression",
    "headerField",
    "minimumId",
    "navigationLinks",
    "path",
    "requestMethod",
    "resource",
    "responseCode",
    "response",
    "validateProfileId",
    "requestURL" # TODO: Discuss this being classified as an 'assert'
  ]
  CODE_MAP = {
    '200' => 'okay',
    '201' => 'created',
    '204' => 'noContent',
    '304' => 'notModified',
    '400' => 'bad',
    '403' => 'forbidden',
    '404' => 'notFound',
    '405' => 'methodNotAllowed',
    '409' => 'conflict',
    '410' => 'gone',
    '412' => 'preconditionFailed',
    '422' => 'unprocessable'
  }

  def evaluate(assert)

    # TODO: Check and fail if assert is nil || not the intended type

    assert_elements = assert.to_hash.keys
    @direction = assert.direction
    assert_type = determine_assert_type(assert_elements)

    # Wrap in Rescue
    outcome_message = send(assert_type.to_sym, assert)
    # stop Test On Fail Check
    # warning Only Check
    # TODO: What happens if the assertion is poorly formed?
      # like, it only uses CompareToSourceID? Do we catch/throw?
  end

  def determine_assert_type(all_elements)
    assert_type = all_elements.detect { |elem| ASSERT_TYPES.include? elem }
    return assert_type.split(ASSERT_TYPES_MATCHER).map(&:downcase).join('_')
  end

  def direction
    @direction ||= 'response'
  end

  def determine_expected_value(assert)
    if assert.value
      assert.value
    elsif assert.compareToSourceExpression
      FHIRPath.evaluate(assert.compareToSourceExpression,
        get_resource(assert.compareToSourceId).to_hash)
    elsif assert.compareToSourcePath
      evaluate_path(assert.compareToSourcePath,
        get_resource(assert.compareToSourceId))
    end
  end

  def compare(assert_type, received, operator, expected = nil)
    operator = 'equals' unless operator
    outcome = begin
      case operator
      when 'equals'
        expected == received
      when 'notEquals'
        expected != received
      when 'in'
        Array.wrap(expected).split(',').include?(Array.wrap(received))
      when 'notIn'
        !Array.wrap(expected).split(',').include?(Array.wrap(received))
      when 'greaterThan'
        received > expected
      when 'lessThan'
        received < expected
      when 'empty'
        received.blank?
      when 'notEmpty'
        received.present?
      when 'contains'
        Array.wrap(received).split(',').include?(Array.wrap(expected))
      when 'notContains'
        !Array.wrap(received).split(',').include?(Array.wrap(expected))
      end
    end

    if outcome
      pass_message(assert_type, received, operator, expected)
    else
      fail_message(assert_type, received, operator, expected)
    end
  end

  def pass_message(assert_type, received, operator, expected)
    message = "#{assert_type}: As expected, #{assert_type} #{operator}"
    message = message + (expected ? " #{expected}."  : '.')
    message + " Found #{received}." if received
  end

  def fail_message(assert_type, received, operator, expected)
    message = "#{assert_type}: Expected #{assert_type} #{operator}"
    message = message + " #{expected}" if expected
    message + ", but found #{received}."
  end

  def content_type(assert)
    received = request_header(assert.sourceId, 'Content-Type')
    expected = determine_expected_value(assert)
    compare("Content-Type", received, assert.operator, expected)
  end

  def expression(assert)
    resource = get_resource(assert.sourceId)
    return unless resource

    # TODO: Clea-up, once integrated with the MessageHandler
    # error("No static fixture, dynamic fixture with ID: #{assert.sourceId}")
    # FHIR.logger.error("No static fixture, dynamic fixture with ID: #{assert.sourceId}")
    # return "No static or dynamic fixture with ID: #{assert.sourceId}"

    received = FHIRPath.evaluate(assert.expression, resource.to_hash)
    expected = determine_expected_value(assert)
    compare("Expression", received, assert.operator, expected)
  end

  def header_field(assert)
    received = begin
      if direction == 'request'
        request_header(assert.sourceId, assert.headerField)
      else
        response_header(assert.sourceId, assert.headerField)
      end
    end

    expected = determine_expected_value(assert)
    compare("Header #{assert.headerField}", received, assert.operator, expected)
  end

  def minimum_id(assert)
    received = get_resource(assert.sourceId)

    return nil # TODO: Return skip

    # result = client.validate(received, { profile_uri: assert.validateProfileId })
    # TODO: Clea-up, once integrated with the MessageHandler
    # skip("Can not validate minimumId #{assert.sourceId || "last response"}. Validation not yet functional.")
    # FHIR.logger.error("Can not validate minimumId #{assert.sourceId || "last response"}. Validation not yet functional.")
    # return "Can not validate minimumId #{assert.sourceId || "last response"}. Validation not yet functional."
  end

  def navigation_links(assert)
    received = get_resource(assert.sourceId)
    received&.first_link && received&.last_link && received&.next_link
  end

  def path(assert)
    resource = get_resource(assert.sourceId)
    received = evaluate_path(assert.path, resource)
    expected = determine_expected_value(assert)
    compare("Path", received, assert.operator, expected)
  end

  def request_method(assert)
    request = assert.sourceId ? request_map[assert.sourceId] : reply.request
    received = request[:method]
    expected = determine_expected_value(assert)
    compare("Request Method", received, assert.operator, expected)
  end

  def resource(assert)
    received = get_resource(assert.sourceId)
    compare("Resource", received&.resourceType, assert.operator, assert.resource)
  end

  def response_code(assert)
    received = get_response(assert.sourceId)&.[](:code)
    compare("Response Code", received, assert.operator, assert.responseCode)
  end

  def response(assert)
    received_code = get_response(assert.sourceId)&.[](:code)
    received = CODE_MAP[received_code]
    compare("Response", received, assert.operator, assert.response)
  end

  def validate_profile_id(assert)
    received = get_resource(assert.sourceId)

    return nil

    # result = client.validate(received, { profile_uri: assert.validateProfileId })
    # TODO: Clea-up, once integrated with the MessageHandler
    # skip("Can not validate #{assert.sourceId || "last response"}. Validation not yet functional.")
    # FHIR.logger.error("Can not validate #{assert.sourceId || "last response"}. Validation not yet functional.")
    # return "Can not validate #{assert.sourceId || "last response"}. Validation not yet functional."
  end

  def request_url(assert)
    received = get_request(assert.sourceId)[:url]
    compare("RequestURL", received, assert.operator, assert.requestURL)
  end


  # <--- TO DO: MOVE TO UTILITIES MODULE --->

  def get_resource(id)
    if direction == 'request'
      get_request(id)&.[](:payload)
    else
      get_response(id)&.[](:body) || fixtures[id]
    end
  end

  def get_response(id)
    return response_map[id] if id
    reply.response
  end

  def get_request(id)
    return request_map[id] if id
    reply.request
  end

  def response_header(responseId = nil, header_name = nil)
    response = responseId ? response_map[responseId] : reply&.response
    return unless response

    headers = response[:headers]
    return unless headers

    header_name ? headers[header_name] : headers
  end

  def request_header(requestId = nil, header_name = nil)
    request = requestId ? request_map[requestId] : reply&.request
    return unless request

    headers = request[:headers]
    return unless headers

    header_name ? headers[header_name] : headers
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
      s.start_with?('fhir:') || s.length.zero? || s.start_with?('@') ? s : "fhir:#{s}"
    end.join('/')
    xpath = "#{xpath}/@value" unless xpath.end_with? '@value'
    xpath = "//#{xpath}"

    resource_doc = Nokogiri::XML(resource_xml)
    resource_doc.root.add_namespace_definition('fhir', 'http://hl7.org/fhir')
    resource_element = resource_doc.xpath(xpath)

    # This doesn't work on warningOnly; consider putting back in place
    # raise AssertionException.new("[#{resource_xpath}] resolved to multiple values instead of a single value", resource_element.to_s) if resource_element.length>1
    resource_element.first.value
  end
end
