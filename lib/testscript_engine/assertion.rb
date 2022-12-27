# frozen_string_literal: true
require 'jsonpath'
require 'json'

module Assertion
  class AssertionException < StandardError
    attr_reader :details, :outcome

    def initialize(details, outcome)
      @details = details
      @outcome = outcome
			super(details)
    end
  end

  @options = {}

  ASSERT_TYPES_MATCHER = /(?<=\p{Ll})(?=\p{Lu})|(?<=\p{Lu})(?=\p{Lu}\p{Ll})/

  ASSERT_TYPES = [
    "contentType",
    "expression",
    "headerField",
    "minimumId",
    "compareToSourceId",
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

  def evaluate(assert, options)
    @direction = assert.direction
    @options = options
    assert_type = determine_assert_type(assert)

    outcome_message = send(assert_type.to_sym, assert)
    pass(:eval_assert_result, outcome_message)
  end

  def determine_assert_type(assert)
    assert_type = check_assert_extensions(assert)
    assert_type = assert.to_hash.keys.detect { |elem| ASSERT_TYPES.include? elem } if assert_type == nil
    return assert_type.split(ASSERT_TYPES_MATCHER).map(&:downcase).join('_')
  end

  def check_assert_extensions(assert)
    if (assert.extension.length > 0 && assert.extension[0].url == "urn:mitre:fhirfoundry:subtest")
      return "subtest"
    end
    return nil
  end

  def direction
    @direction ||= 'response'
  end

  def determine_expected_value(assert)
    if assert.value
      assert.value
    elsif assert.compareToSourceExpression
      evaluate_expression(assert.compareToSourceExpression, get_resource(assert.compareToSourceId))
    elsif assert.compareToSourcePath
      evaluate_path(assert.compareToSourcePath, get_resource(assert.compareToSourceId))
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
    raise AssertionException.new('Expression: No resource given by sourceId.', :fail) unless resource
    raise AssertionException.new("Expression: Operator '#{assert.operator}' not supported in expression. Support only 'equals'", :fail) if assert.operator != nil && assert.operator != "equals"

    received = evaluate_expression(assert.expression, resource)
    if !received.is_a?(Array)
      received_value = received
    elsif received.length == 0
      raise AssertionException.new('Expression: no value returned.', :fail)
    elsif received.length > 1
      raise AssertionException.new('Expression: multiple values returned.', :fail)
    else
      received_value = received[0]
    end
    expected = determine_expected_value(assert)
    compare("Expression", received_value.to_s, assert.operator, expected.to_s)
  end

  def compare_to_source_id(assert)
    resource = get_resource(assert.sourceId)
    compare_to_resource = get_resource(assert.compareToSourceId)
    raise AssertionException.new('CompareToSourceId: No resource given by sourceId.', :fail) unless resource
    raise AssertionException.new('CompareToSourceId: No resource given by compareToSourceId.', :fail) unless compare_to_resource
    
    received = evaluate_expression(assert.expression, resource)
    if !received.is_a?(Array)
      received_value = received
    elsif received.length == 0
      raise AssertionException.new('CompareToSourceId: no value returned.', :fail)
    elsif received.length > 1
      raise AssertionException.new('CompareToSourceId: multiple values returned.', :fail)
    else
      received_value = received[0]
    end
    expected = evaluate_expression(assert.compareToSourceExpression, compare_to_resource)
    if !expected.is_a?(Array)
      expected_value = received
    elsif expected.length == 0
      raise AssertionException.new('CompareToSourceId: no expected value returned.', :fail)
    elsif expected.length > 1
      raise AssertionException.new('CompareToSourceId: multiple expected values returned.', :fail)
    else
      expected_value = expected[0]
    end
    compare("CompareToSourceId", received_value.to_s, assert.operator, expected_value.to_s)
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

  def validate_profile_id(assert)

    ext_validator_url = @options["ext_validator"]
    sourceId = assert.sourceId
    validateProfileId = assert.validateProfileId
    profile = profiles[validateProfileId]

    if ext_validator_url == nil #Run internal validator
      print_out " validateProfileId: trying the Ruby Crucible validator"
      validation_issues = profile.validate_resource(get_resource(sourceId))
      passed = validation_issues.empty?
      

      if validation_issues.empty?
        return "#{sourceId ? "Fixture '#{sourceId}'" : "The last response"} conforms to profile '#{validateProfileId}'."
      else
        message = validation_issues.reduce("") { |ag_text, one_issue| "#{ag_text}#{";" unless ag_text == ""} #{one_issue}" }
        fail_message = "#{sourceId ? "Fixture '#{sourceId}'" : "The last response"} does not conform to profile '#{validateProfileId}'.#{message ? " Details -#{message}" : ""}"
        raise AssertionException.new(fail_message, :fail)
      end

    else #Run external validator
      print_out " validateProfileId: trying external validator '#{ext_validator_url}'"
      
      # Assumes profile is available on the external validator
      # this step is handled by TestScriptEngine.load_profiles

      path = ext_validator_url+"/validate?profile=#{profile.url}"
      reply = client_util.send(:post, path, get_resource(sourceId), { 'Content-Type' => 'json' })

      if reply.response[:code].start_with?("2")
        result = FHIR.from_contents(reply.response[:body].body)
        passed = result.issue.reduce(true) { |pass_ag, one_issue| pass_ag && (one_issue.severity != "error")}
        message = external_result_to_string(result)
        if passed
          return "#{sourceId ? "Fixture '#{sourceId}'" : "The last response"} conforms to profile '#{validateProfileId}'.#{message ? " Details -#{message}" : ""}"
        else
          fail_message = "#{sourceId ? "Fixture '#{sourceId}'" : "The last response"} does not conform to profile '#{validateProfileId}'.#{message ? " Details -#{message}" : ""}"
          raise AssertionException.new(fail_message, :fail)
        end        
      else
        fail_message = "Failed, response code : #{reply.response[:code]}."
        raise AssertionException.new(fail_message, :fail)
      end

    end
  end

  def external_result_to_string(result)
    result.issue.reduce("") { |ag_text, one_issue| "#{ag_text}#{";" unless ag_text == ""} #{issue_to_string(one_issue)}" }
  end

  def issue_to_string(issue)
    location = get_issue_location(issue)
    
    "#{issue.severity}#{location}: #{issue.details.text}"
  end

  def get_issue_location(issue)
    line_extension = issue.extension.find { |ext| ext.url == "http://hl7.org/fhir/StructureDefinition/operationoutcome-issue-line"}
    column_extension = issue.extension.find { |ext| ext.url == "http://hl7.org/fhir/StructureDefinition/operationoutcome-issue-col"}
    
    prefix = "at"
    expression = issue.expression.length > 0 ? " #{issue.expression[0]}" : ""
    line = line_extension ? " Line #{line_extension.valueInteger.to_s}" : ""
    column = column_extension ? " Col #{column_extension.valueInteger.to_s}" : ""
    suffix = expression + line + column
    
    if suffix
      return " at" + suffix
    else
      return ""
    end
  end

  def minimum_id(assert)
    raise AssertionException.new('No given sourceId.', :fail) unless assert.sourceId

    specErrorPaths = []
    path = ""
    outcome = check_minimum_id(get_resource(assert.minimumId).to_hash, get_resource(assert.sourceId).to_hash, path, specErrorPaths)
    
    if outcome
      "minimumId: As expected, minimum content from fixture '#{assert.minimumId}' found in '#{assert.sourceId == nil ? "the latest response" : assert.sourceId}'."
    else
      fail_message = "minimunId: content from fixture '#{assert.minimumId}' not found in '#{assert.sourceId == nil ? "the latest response" : assert.sourceId}'. Differences found at path#{"s" unless specErrorPaths.count < 2}: "
      specErrorPaths.each_index { |_index| fail_message << (_index == 0 ? specErrorPaths[_index] : ", #{specErrorPaths[_index]}") }
      fail_message << "."
      raise AssertionException.new(fail_message, :fail)
    end
  end

  def check_minimum_id(spec, actual, currentSpecPath, specErrorPaths)
    if spec.is_a?(Hash) && actual.is_a?(Hash)
        return check_minimum_id_hash(spec, actual, currentSpecPath, specErrorPaths)
    end

    if spec.is_a?(Array) && actual.is_a?(Array)
        return check_minimum_id_array(spec, actual, currentSpecPath, specErrorPaths)
    end

    if spec == actual
      return true
    else
      specErrorPaths.push(currentSpecPath)
      return false
    end
  end

  def check_minimum_id_hash(spec, actual, currentSpecPath, specErrorPaths)
    pass_flg = true
  
    spec.each do |k, v|
      newSpecPath = currentSpecPath.length == 0 ? k : currentSpecPath + ".#{k}"
      keyResult = check_minimum_id(spec[k], actual[k], newSpecPath, specErrorPaths)
      pass_flg = keyResult && pass_flg
    end

    return pass_flg
  end

  def check_minimum_id_array(spec, actual, currentSpecPath, specErrorPaths)
    pass_flg = true

    spec.each_index do |_index|
      _spec = spec[_index]
      found_flg = false
      newPath = currentSpecPath + "[#{_index}]"
      actual.each do |_actual|
        if check_minimum_id(_spec, _actual, newPath, []) # drop errors under list entries
          actual.delete(_actual) 
          found_flg = true
          break
        end
      end
      if (!found_flg)
        specErrorPaths.push(newPath)
      end
      pass_flg = pass_flg && found_flg
    end

    return pass_flg
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

  def request_url(assert)
    received = get_request(assert.sourceId)[:url]
    compare("RequestURL", received, assert.operator, assert.requestURL)
  end

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

  def subtest(assert)
    subtest_ext = assert.extension.find { |one_ext| one_ext.url == "urn:mitre:fhirfoundry:subtest"}
    raise AssertionException.new("Missing subtest extension", :fail ) unless subtest_ext
    testname_ext = subtest_ext.extension.find {|one_sub_ext| one_sub_ext.url == "urn:mitre:fhirfoundry:subtest:name"}
    raise AssertionException.new("Missing subtest name extension", :fail ) unless testname_ext
    binding_ext_list = subtest_ext.extension.select {|one_sub_ext| one_sub_ext.url == "urn:mitre:fhirfoundry:subtest:bindVariable"}
    test_name = testname_ext.valueString

    runnable = engine.runnables[test_name]
    raise AssertionException.new("Runnable with name '#{test_name}' not loaded", :fail ) unless runnable
    runnable_copy = runnable.clone
    runnable_copy.bound_variables = runnable_copy.bound_variables.clone

    # bind variables
    binding_ext_list.each { |binding_ext|
      
      # get source value
      source_ext = binding_ext.extension.find {|one_sub_ext| one_sub_ext.url == "urn:mitre:fhirfoundry:subtest:bindVariable:sourceVariable"}
      raise AssertionException.new("Missing source variable extension for binding", :fail ) unless source_ext
      source_variable_name = source_ext.valueString
      source_variable = script.variable.find { |one_source_var| one_source_var.name == source_variable_name}
      raise AssertionException.new("Missing source variable with name '#{source_variable_name}' in script '#{script.name}'", :fail ) unless source_variable
      source_value = evaluate_variable(source_variable)
      raise AssertionException.new("Missing value for variable with name '#{source_variable_id}' in script '#{script.name}'", :fail ) unless source_value
    
      # add to target binding
      target_ext = binding_ext.extension.find {|one_sub_ext| one_sub_ext.url == "urn:mitre:fhirfoundry:subtest:bindVariable:targetVariable"}
      raise AssertionException.new("Missing target variable extension for binding", :fail ) unless target_ext
      target_variable_name = target_ext.valueString
      target_variable = runnable_copy.script.variable.find { |one_target_var| one_target_var.name == target_variable_name }
      raise AssertionException.new("Missing target variable with name '#{target_variable_name}' in script '#{test_name}'", :fail ) unless target_variable
      runnable_copy.bound_variables[target_variable_name] = source_value
    }

    runnable_copy.increase_space
    runnable_copy.increase_space
    report = runnable_copy.run(client)
    engine.reports << report
    if report.result == 'fail'
      raise AssertionException.new("subtest '#{testname_ext.valueString}' execution failed", :fail)
    end


    return "subtest '#{testname_ext.valueString}' execution succeeded"

  end
end
