# frozen_string_literal: true
require 'pry-nav'
module Assertions

  CODE_MAP = {
    'okay' => 200,
    'created' => 201,
    'noContent' => 204,
    'notModified' => 304,
    'bad' => 400,
    'forbidden' => 403,
    'notFound' => 404,
    'methodNotAllowed' => 405,
    'conflict' => 409,
    'gone' => 410,
    'preconditionFailed' => 412,
    'unprocessable' => 422,
    nil => 422
  }.freeze

  class AssertionException < RuntimeError
    attr_accessor :data

    def initialize(message, data = nil)
      super(message)
      @data = data
    end
  end

  def assert_compare_to_source_expression assertion
    resource = fixtures[assertion.compareToSourceId]
    raise_exception('[.assert_compare_to_source_expression]', 'noFixture', assertion.compareToSourceId) unless resource

    begin
      unless FHIRPath.evaluate(assertion.compareToSourceExpression, resource.to_hash)
        raise_exception('[.assert_compare_to_source_expression]', 'falseExpression', assertion.compareToSourceExpression, "with fixture id: #{resource.compareToSourceId}")
      end
    rescue => fpe
      raise fpe if fpe.class == Assertions::AssertionException
      raise_exception('[.assert_compare_to_source_expression]', 'invalidExpression', assertion.compareToSourceExpression)
    end
  end

  def assert_compare_to_source_path assertion
    resource = fixtures[assertion.compareToSourceId]
    raise_exception('[.assert_compare_to_source_path]', 'noFixture', assertion.compareToSourceId) unless resource

    expected = evaluate_path(assertion.compareToSourcePath, resource)
    raise_exception('[.assert_compare_to_source_path]', 'badExtraction', "with fixture id: #{assertion.compareToSourceId}", assertion.compareToSourcePath) unless expected

    actual = evaluate_path(assertion.path, assert_find_resource(assertion.sourceId, '[.assert_compare_to_source_path]'))
    raise_exception('[.assert_compare_to_source_path]', 'badExtraction', assertion.sourceId ? "with fixture id: #{assertion.sourceId}" : "returned by server", assertion.path) unless actual

    assert_operator(actual, assertion.operator, expected, '[.assert_compare_to_source_path]')
  end

  def assert_content_type assertion
    header = reply.response[:headers]['content-type']
    raise_exception('[.assert_content_type]', 'noContentType', 'content-type') unless header

    value = header.split(';').find { |x| x == assertion.contentType }
    raise_exception('[.assert_content_type]', 'badContentType', assertion.contentType, header) unless value
  end

  def assert_find_resource(id, location)
    resource = response_map[id]&.resource || fixtures[id] || reply&.resource
    resource || raise_exception(location, 'noResource', "with id: #{id}" || '')
  end

  def assert_expression assertion
    resource = assert_find_resource(assertion.sourceId, '[.assert_expression]')
    begin
      unless FHIRPath.evaluate(assertion.expression, resource.to_hash) == true
        raise_exception('[.assert_expression]', 'falseExpression', assertion.expression, assertion.sourceId ? "with id: #{assertion.sourceId}" : 'in latest reply from server')
      end
    rescue => fpe
      raise fpe if fpe.class == Assertions::AssertionException
      raise_exception('[.assert_expression]', 'invalidExpression', assertion.expression)
    end
  end

  def assert_header_field assertion
    to_assert_on = assertion.sourceId ? response_map[assertion.sourceId] : reply
    if assertion.direction == 'request'
      header_value = to_assert_on.request[:headers][assertion.headerField.downcase]
      prefix = 'Request'
    else
      header_value = to_assert_on.response[:headers][assertion.headerField.downcase]
      prefix = 'Response'
    end

    raise_exception('[.assert_header_field]', 'noValue') unless assertion.value || (['empty', 'notEmpty'].include? assertion.operator)
    assert_operator(header_value, assertion.operator, replace_variables(assertion.value), "[.assert_header_field] #{prefix} Header Field #{assertion.headerField} --")
  end

  def assert_minimum_id assertion
    resource = assert_find_resource(assertion.sourceId, '[.assert_minimum_id]')
    min_resource = response_map[assertion.minimumId] || fixtures[assertion.minimumId]
    raise_exception('[.assert_minimum_id]', 'noResource', "with id: #{assertion.minimumId}") unless min_resource
    raise_exception('[.assert_minimum_id]', 'noMinimum', assertion.sourceId ? "with id: #{assertion.sourceId}" : "in last response" , "#{assertion.minimumId}") unless min_compare_hashes(min_resource.to_hash, resource.to_hash)
  end

  def min_compare_hashes(min_hash, targ_hash)
    return false unless (min_hash.keys - targ_hash.keys).empty?

    return min_hash.all? do |k, v|
      return true if v.is_a? String
      return min_compare_hashes(v, targ_hash[k]) if v.is_a? Hash
      return min_compare_arrays(v, targ_hash[k]) if v.is_a? Array
    end
  end

  def min_compare_arrays(min_arr, targ_arr)
    return min_arr.all? do |min|
      return true if min.is_a? String
      targ_arr.any? do |targ|
        return min_compare_hashes(min, targ) if min.is_a? Hash and targ.is_a? Hash
        return min_compare_arrays(min, targ) if min.is_a? Array and targ.is_a? Array
      end
    end
  end

  def assert_navigation_links assertion
    resource = assert_find_resource(assertion.sourceId, '[.assert_navigation_links]')
    links = resource.first_link && resource.last_link && resource.next_link
    raise_exception('[.assert_navigation_links]', 'noLinks') if !links and assertion.navigationLinks
    raise_exception('[.assert_navigation_links]', 'yesLinks') if links and !assertion.navigationLinks
  end

  def assert_path assertion
    resource = assert_find_resource(assertion.sourceId, '[.assert_path]')

    raise_exception('[.assert_path]', 'noValue') unless assertion.value || (['empty', 'notEmpty'].include? assertion.operator)
    assert_operator(evaluate_path(assertion.path, resource), assertion.operator, replace_variables(assertion.value), '[.assert_path]')
  end

  def assert_request_method assertion
    assert_operator(reply.request[:method].to_s, assertion.operator, replace_variables(assertion.requestMethod), '[.assert_request_method]')
  end

  def assert_request_url assertion
    assert_operator(reply.request[:url], assertion.operator, replace_variables(assertion.requestURL), '[.assert_request_url]')
  end

  def assert_response assertion
    to_assert_on = response_map[assertion.sourceId] || reply
    expected = CODE_MAP[assertion.response]
    assert_operator(to_assert_on&.code, assertion.operator, expected, '[.assert_response]')
  end

  def assert_response_code assertion
    to_assert_on = response_map[assertion.sourceId] || reply
    assert_operator(to_assert_on&.code&.to_s, assertion.operator, assertion.responseCode, '[.assert_response_code]')
  end

  def assert_resource assertion
    resource = assert_find_resource(assertion.sourceId, '[.assert_resource]')
    assert_operator(resource.resourceType, assertion.operator, assertion.resource, '[.assert_resource]')
  end

  def assert_validate_profile_id assertion
    uri = script.profile.find { |profile| profile.id == assertion.validateProfileId }.reference
    response = client.validate(reply.response, { profile_uri: uri } )

    raise_exception('noValidation', '[.assert_valid_profile_id]', reply.resource.resourceType) if response.code.to_s == "201"
    raise_exception('badValidation', '[.assert_valid_profile_id]', response.code)  if response.code.to_s != "200"
  end

  def assert_operator(actual, operator, expected, message = '', data = '')
    operator = operator.try(:to_sym) || :equals
    fail_message = String.new
    expected = 'nothing' unless expected or ['empty', 'notEmpty'].include? operator
    actual = 'nothing' unless actual or ['empty', 'notEmpty'].include? operator

    case operator
    when :equals
      fail_message += " Expected #{expected} but found #{actual}." unless actual == expected
    when :notEquals
      fail_message += " Did not expect #{expected} but found #{actual}." unless actual != expected
    when :in
      fail_message += " Expected #{expected} but found #{actual}." unless expected.split(',').include?(actual)
    when :notIn
      fail_message += " Did not expect #{expected} but found #{actual}." if expected.split(',').include?(actual)
    when :greaterThan
      fail_message += " Expected greater than #{expected} but found #{actual}." unless actual && expected && actual > expected
    when :lessThan
      fail_message += " Expected greater than #{expected} but found #{actual}." unless actual && expected && actual < expected
    when :empty
      fail_message += " Expected empty but found #{actual}." unless actual.nil? || actual.length.zero?
    when :notEmpty
      fail_message += " Expected not empty but found #{actual}." unless actual&.length&.positive?
    when :contains
      fail_message += " Expected #{actual} to contain #{expected}." unless actual&.include?(expected)
    when :notContains
      fail_message += " Expected #{actual} to not contain #{expected}." unless actual.nil? || !actual.include?(expected)
    else
      fail_message += " Invalid test due to unknown operator: #{operator}."
    end

    raise AssertionException.new (message + fail_message) unless fail_message.empty?
  end

  def raise_exception(location, message_type, *info)
    case message_type
    when 'badContentType'
      location += " Expected content-type with value: #{info[0]}, but found value: #{info[1]}."
    when 'badExtraction'
      location += " Could not extract element from resource #{info[0]} using path: #{info[1]}."
    when 'falseExpression'
      location += " Expression: #{info[0]} did not evaluate to true for resource stored #{info[1]}. FHIRPath Expressions must evaluate to true."
    when 'invalidExpression'
      location += " Invalid Expression: #{info[0]}. Valid FHIRPath Expression is required."
    when 'noContentType'
      location += " Expected #{info[0]} header not included in response."
    when 'noFixture'
      location += " Expected resource stored in fixtures with id: #{info[0]}. No such resource found."
    when 'noLinks'
      location += " Bundle resource does not contain first, last, and next links as expected."
    when 'noMinimum'
      location += " Resource #{info[0]} does not have minimum content of resource with id: #{info[1]}."
    when 'noResource'
      location += " Expected resource #{info[0]} in fixtures, responses, or in last reply from server. No such resource found."
    when 'noValue'
      location += " Expected assertion.value to be defined. Assertion unprocessable without value."
    when 'yesLinks'
      location += " Bundle resource contains first, last, and next links, but no navigation links were expected."
    when 'noValidation'
      location += " Server created a #{info[0]} with the ID `_validate` rather than validate the resource."
    end

    raise AssertionException.new location
  end
end
