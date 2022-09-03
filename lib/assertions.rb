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

  # TODO: Move to utilities
  def get_resource(id)
    response_map[id][:body] || fixtures[id] || reply.resource
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

  def compare(assert_type, received, operator = 'equals', expected = nil)
    case operator
    when 'equals'
      if expected == received
        pass_message(assert_type, received, 'equals', expected)
      else
        fail_message(assert_type, received, 'equals', expected)
      end
    when 'notEquals'
      if expected != received
        pass_message(assert_type, received, 'did not equal', expected)
      else
        fail_message(assert_type, received, 'did not equal', expected)
      end
    when 'in'
      if Array.wrap(expected).split(',').include?(Array.wrap(received))
        pass_message(assert_type, received, 'in', expected)
      else
        fail_message(assert_type, received, 'be in', expected)
      end
    when 'notIn'
      if !Array.wrap(expected).split(',').include?(Array.wrap(received))
        pass_message(assert_type, received, 'not in', expected)
      else
        fail_message(assert_type, received, 'not be in', expected)
      end
    when 'greaterThan'
      if received > expected
        pass_message(assert_type, received, 'greater than', expected)
      else
        fail_message(assert_type, received, 'be greater than', expected)
      end
    when 'lessThan'
      if received < expected
        pass_message(assert_type, received, 'less than', expected)
      else
        fail_message(assert_type, received, 'be less than', expected)
      end
    when 'empty'
      if received.blank?
        pass_message(assert_type, received, 'empty', expected)
      else
        fail_message(assert_type, received, 'be empty', expected)
      end
    when 'notEmpty'
      if received.present?
        pass_message(assert_type, received, 'not empty', expected)
      else
        fail_message(assert_type, received, 'not be empty', expected)
      end
    when 'contains'
      if Array.wrap(received).split(',').include?(Array.wrap(expected))
        pass_message(assert_type, received, 'contains', expected)
      else
        fail_message(assert_type, received, 'contain', expected)
      end
    when 'notContains'
      if !Array.wrap(received).split(',').include?(Array.wrap(expected))
        pass_message(assert_type, received, 'did not contain', expected)
      else
        fail_message(assert_type, received, 'not contain', expected)
      end
    end
  end

  def compare_message(outcome, ...)
    if outcome
      pass_message(...)
    else
      fail_message(...)
    end
  end


  def pass_message(assert_type, received, operator, expected)
    message = "#{assert_type}: As expected, #{assert_type} #{operator}"
    message = message + (expected ? " #{expected}."  : '.')
    message + " Found #{received}." if received
  end

  def fail_message(assert_type, received, operator, expected)
    message = "#{assert_type}: Expected #{assert_type} to #{operator}"
    message = message + " #{expected}" if expected
    message + ", but found #{received}."
  end

  def content_type(assert)
    received = begin
      if assert.sourceId
        request_header(assert.sourceId, 'content-type')
      else
        request_header(nil, 'content_type')
      end
    end

    expected = determine_expected_value(assert)
    compare("Content-Type", received, assert.operator, expected)
  end

  def expression(assert)
    resource = begin
      if assert.sourceId
        if assert.direction == 'request'
          request_map[assert.sourceId][:payload]
        else
          response_map[assert.sourceId].resource&.to_hash
        end
      else
        reply.resource&.to_hash
      end
    end

    # TODO: Clea-up, once integrated with the MessageHandler
    error("No static fixture, dynamic fixture with ID: #{assert.sourceId}") unless resource
    FHIR.logger.error("No static fixture, dynamic fixture with ID: #{assert.sourceId}")
    return "No static fixture, dynamic fixture with ID: #{assert.sourceId}"

    received = FHIRPath.evaluate(assert.expression, resource)
    expected = determine_expected_value(assert)
    compare("Expression", received, assert.operator, expected)
  end

  def header_field(assert)
    received = begin
      if assert.direction == 'request'
        if assert.sourceId
          request_header(assert.sourceId, assert.headerField)
        else
          request_header(nil, assert.headerField)
        end
      else
        if assert.sourceId
          response_header(assert.sourceId, assert.headerField)
        else
          response_header(nil, assert.headerField)
        end
      end
    end

    expected = determine_expected_value(assert)
    compare("Header #{assert.headerField}", received, assert.operator, expected)
  end

  def minimum_id(assert)
    received = begin
      if assert.sourceId
        response_map[assert.sourceId]&.resource || fixtures[assert.sourceId]
      else
        reply.resource
      end
    end

    # result = client.validate(received, { profile_uri: assert.validateProfileId })
    # TODO: Clea-up, once integrated with the MessageHandler
    skip("Can not validate minimumId #{assert.sourceId || "last response"}. Validation not yet functional.")
    FHIR.logger.error("Can not validate minimumId #{assert.sourceId || "last response"}. Validation not yet functional.")
    return "Can not validate minimumId #{assert.sourceId || "last response"}. Validation not yet functional."
  end

  def navigation_links(assert)
    received = begin
      if assert.sourceId
        response_map[assert.sourceId]&.resource || fixtures[assert.sourceId]
      else
        reply.resource
      end
    end

    received&.first_link && received&.last_link && received&.next_link
  end

  def path(assert)
    received = begin
      if assert.sourceId
        response_map[assert.sourceId]&.resource || fixtures[assert.sourceId]
      else
        reply.resource
      end
    end

    received = evaluate_path(assert.path, received)
    expected = determine_expected_value(assert)
    compare("Path", received, assert.operator, expected)
  end

  def request_method(assert)
    received = begin
      if assert.sourceId
        request_map[assert.sourceId]
      else
        reply.request
      end
    end

    compare("Request Method", )
  end

  def resource(assert)
    received = begin
      if assert.sourceId
        response_map[assert.sourceId]&.resource
      else
        reply.resource
      end
    end

    compare("Resource", received&.resourceType, assert.operator, assert.resource)
  end

  def response_code(assert)
    received = begin
      if assert.sourceId
        response_map[assert.sourceId][:code]
      else
        reply.response[:code]
      end
    end

    compare("Response Code", received, assert.operator, assert.responseCode)
  end

  def response(assert)
    received_code = begin
      if assert.sourceId
        response_map[assert.sourceId][:code]
      else
        reply.response[:code]
      end
    end

    received = CODE_MAP[received_code]
    compare("Response", received, assert.operator, assert.response)
  end

  def validate_profile_id(assert)
    received = begin
      if assert.sourceId
        response_map[assert.sourceId]&.resource || fixtures[assert.sourceId]
      else
        reply.resource
      end
    end

    # result = client.validate(received, { profile_uri: assert.validateProfileId })
    # TODO: Clea-up, once integrated with the MessageHandler
    skip("Can not validate #{assert.sourceId || "last response"}. Validation not yet functional.")
    FHIR.logger.error("Can not validate #{assert.sourceId || "last response"}. Validation not yet functional.")
    return "Can not validate #{assert.sourceId || "last response"}. Validation not yet functional."
  end

  def request_url(assert)
    received = begin
      if assert.sourceId
        request_map[assert.sourceId].request[:url]
      elsif
        reply.request[:url]
      end
    end

    compare("RequestURL", reply.request[:url], assert.operator, assert.requestURL)
  end

  # TODO: What should be done here? Make a plan, stick with it
  # I'm thinking a shared utilities file

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
