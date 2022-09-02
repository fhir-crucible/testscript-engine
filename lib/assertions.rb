# frozen_string_literal: true
require 'pry-nav'
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

  def determine_expected_value(assert)
    if assert.value
      assert.value
    elsif assert.compareToSourceExpression
      FHIRPath.evaluate(assert.expression, (response_map[assert.compareToSourceId] || fixtures[assert.compareToSourceId]))
    elsif assert.compareToSourcePath
      evaluate_path(assert.path, (response_map[assert.compareToSourceId] || fixtures[assert.compareToSourceId]))
    end
  end

  def compare(assert_type, received, operator = 'equals', expected = nil)
    case operator
    when 'equals'
      if expected == received
        pass("#{assert_type}: As expected, #{assert_type} equals #{expected}. Found #{received}.")
      else
        fail("#{assert_type}: Expected #{assert_type} to equal #{expected}, but found #{received}.")
      end
    when 'notEquals'
      if expected != received
        pass("#{assert_type}: As expected, #{assert_type} does not equal #{expected}. Found #{received}.")
      else
        fail("#{assert_type}: Expected #{assert_type} to not equal #{expected}, but found #{received}.")
      end
    when 'in'
      if expected.split(',').include?(received)
        pass("#{assert_type}: As expected, #{assert_type} in #{expected}. Found #{received}.")
      else
        fail("#{assert_type}: Expected #{assert_type} to be in #{expected}, but found #{received}.")
      end
    when 'notIn'
      if !expected.split(',').include?(received)
        pass("#{assert_type}: As expected, #{assert_type} not in #{expected}. Found #{received}.")
      else
        fail("#{assert_type}: Expected #{assert_type} to not be in #{expected}, but found #{received}.")
      end
    when 'greaterThan'
      if received > expected
        pass("#{assert_type}: As expected, #{assert_type} greater than #{expected}. Found #{received}.")
      else
        fail("#{assert_type}: Expected #{assert_type} to be greater than #{expected}, but found #{received}.")
      end
    when 'lessThan'
      if received < expected
        pass("#{assert_type}: As expected, #{assert_type} less than #{expected}. Found #{received}.")
      else
        fail("#{assert_type}: Expected #{assert_type} to be less than #{expected}, but found #{received}.")
      end
    when 'empty'
      if received.nil || received.empty?
        pass("#{assert_type}: As expected, #{assert_type} empty.")
      else
        fail("#{assert_type}: Expected #{assert_type} to be empty, but found #{received}.")
      end
    when 'notEmpty'
      if received && !received.empty?
        pass("#{assert_type}: As expected, #{assert_type} not empty. Found #{received}.")
      else
        fail("#{assert_type}: Expected #{assert_type} to not be empty, but found #{received}.")
      end
    when 'contains'
      if received.include?(expected)
        pass("#{assert_type}: As expected, #{assert_type} contains #{expected}. Found #{received}")
      else
        fail("#{assert_type}: Expected #{assert_type} to contain #{expected}, but found #{received}.")
      end
    when 'notContains'
      if !received.include?(expected)
        pass("#{assert_type}: As expected, #{assert_type} did not contain #{expected}. Found #{received}")
      else
        fail("#{assert_type}: Expected #{assert_type} to not contain #{expected}, but found #{received}.")
      end
    end
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
    binding.pry
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
end
