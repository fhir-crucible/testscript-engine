# frozen_string_literal: true
require 'jsonpath'
require 'httparty'

module Assertion
  class AssertionException < StandardError
    attr_reader :details, :outcome

    def initialize(details, outcome)
      @details = details
      @outcome = outcome
			super(details)
    end
  end

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
    "requestURL"
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
    @direction = assert.direction
    assert_elements = assert.to_hash.keys
    assert_type = determine_assert_type(assert_elements)

    outcome_message = send(assert_type.to_sym, assert)

    pass(:eval_assert_result, outcome_message)
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
      evaluate_expression(assert.compareToSourceExpression,
        get_resource(assert.compareToSourceId))
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
        expected.split(',').include? received
      when 'notIn'
        !expected.split(',').include? received
      when 'greaterThan'
        received.to_i > expected.to_i
      when 'lessThan'
        received.to_i < expected.to_i
      when 'empty'
        received.blank?
      when 'notEmpty'
        received.present?
      when 'contains'
        received&.include? expected
      when 'notContains'
        !received&.include? expected
      when 'isProfileOf'
        profiles[expected].validates_resource?(get_resource(received))
      end
    end

    if outcome
      pass_message(assert_type, received, operator, expected)
    else
      fail_message = fail_message(assert_type, received, operator, expected)
      raise AssertionException.new(fail_message, :fail)
    end
  end

  def pass_message(assert_type, received, operator, expected)
    received = Array(received)
    expected = Array(expected)
    message = "#{assert_type}: As expected, #{assert_type} #{operator}"
    message = message + (expected ? " #{expected}."  : '.')
    message + " Found #{received}." if received
  end

  def fail_message(assert_type, received, operator, expected)
    received = Array(received)
    expected = Array(expected)
    message = "#{assert_type}: Expected #{assert_type} #{operator}"
    message = message + " #{expected}" if expected
    message + ", but found #{received}."
  end

  def content_type(assert)
    received = request_header(assert.sourceId, 'Content-Type')
    compare("Content-Type", received, assert.operator, assert.contentType)
  end

  def expression(assert)
    resource = get_resource(assert.sourceId)
    raise AssertionException.new('No resource given by sourceId.', :fail) unless resource

    received = evaluate_expression(assert.expression, resource)
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

    raise AssertionException.new('minimumId assert not yet supported.', :skip)
    # result = client.validate(received, { profile_uri: assert.validateProfileId })
  end

  def navigation_links(assert)
    received = get_resource(assert.sourceId)
    result = received&.first_link && received&.last_link && received&.next_link

    return "Navigation Links: As expected, all navigation links found." if result

    raise AssertionException.new("Navigation Links: Expected all navigation links, but did not receive.", :fail)
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
    received = get_response(assert.sourceId)&.[](:code).to_s
    compare("Response Code", received, assert.operator, assert.responseCode)
  end

  def response(assert)
    received_code = get_response(assert.sourceId)&.[](:code).to_s
    received = CODE_MAP[received_code]
    compare("Response", received, assert.operator, assert.response)
  end

  def validate_profile_id(assert)
    compare("validateProfileId", assert.sourceId, 'isProfileOf', assert.validateProfileId)
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
    reply&.response
  end

  def get_request(id)
    return request_map[id] if id
    reply&.request
  end

  def response_header(responseId = nil, header_name = nil)
    response = responseId ? response_map[responseId] : reply&.response
    return unless response

    headers = response[:headers]
    return unless headers

    headers.transform_keys!(&:downcase)
    header_name ? headers[header_name.downcase] : headers
  end

  def request_header(requestId = nil, header_name = nil)
    request = requestId ? request_map[requestId] : reply&.request
    return unless request

    headers = request[:headers]
    return unless headers

    headers.transform_keys!(&:downcase)
    header_name ? headers[header_name.downcase] : headers
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
