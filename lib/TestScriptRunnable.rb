# Design Choice Explanation --> I designed this to give all users as much flexibility as possible, especially considering
# how much good stuff was in crucible that was kinda packaged away. So, each method is going to remain public, and should
# be usable. This means that initializing doesn't really do much beyond storing. 

#TODO: Determine Ruby style on using ternary vs full if-block
#TODO: Clean-up!! Big time
#TODO: Design choice -- should methods be private? 
#TODO: Be decisive and consistent on error handling

require 'pry-nav'
require 'jsonpath'
require_relative 'assertions'
require 'fhir_client'

class TestScriptRunnable

	include Assertions

	FORMAT_MAP = {
		nil => FHIR::Formats::ResourceFormat::RESOURCE_JSON,
		'json' => FHIR::Formats::ResourceFormat::RESOURCE_JSON,
		'xml' => FHIR::Formats::ResourceFormat::RESOURCE_XML
	}

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
		'unprocessable' => 422
	}

	attr_accessor :fixtures
	attr_accessor :id_map
	attr_accessor :tScript
	attr_accessor :autocreate
	attr_accessor :autodelete 

	def initialize(tScript)

		unless tScript.is_a?(FHIR::TestScript) 
			FHIR.logger.error '[TestScriptRunnable.initialize] Received invalid TestScript: can not initialize TestScriptRunnable.'
			return
		end 

		@tScript = tScript
		@last_reply = nil
		# TODO: Set this to nil and then have the engine set the client when 
		#				executing the runnable
		@client = FHIR::Client.new('http://localhost:8080/fhir/')
		@report = FHIR::TestReport.new

		@fixtures = {}
		@id_map = {}		
		@response_map = {}

		@autocreate = []
		@autodelete = []
		@executables = []

		initialize_report 
		load_fixtures # --> Good to go!
		load_tests

		#sprinkler_read_test_r004_r004_test
		#load_setup
		#load_setup
		#setup
		#load_tests
		#remove_instance_variable(:@tScript)
		#read_patient_01_readpatient_test
		#binding.pry
	end 
	
	def initialize_report
		@report.id = @tScript.id
		@report.name = @tScript.name
		@report.status = 'waiting'
		@report.result = 'pending'
	end 

	def execute
		@executables.each do |executable|
			@report.test << self.method(executable).call
		end 

		return @report
		# if @client == nil, return nil and output an error saying we need a valid client! no excuse for that
		# Or check if destination is set ... 
		# Setup the testreport template
		# Setup client
		# Do Setup (including autocreate and autodelete and all that jazz)
		# Execute tests
		# tear down 
	end 

	# TODO: More idiomatic way of doing this? More a motif than its own method
	def find_resource(container)
		@fixtures[id] || pull_resource(@response_map[id])
	end 

	def pull_resource(container)
		container.try(:resource) || FHIR.from_contents(container.body)
	end 

	# Updates @fixtures, @autocreate, and @autodelete using @tScript.fixtures.
	def load_fixtures
		return if @tScript.fixture.nil?
		@tScript.fixture.each do |fixture|
			@fixtures[fixture.id] = get_reference(fixture.resource.reference)
			@autocreate << fixture.id if fixture.autocreate
      @autodelete << fixture.id if fixture.autodelete
		end 
	end 

	# TODO: Review and add unit tests.
	def get_reference(reference)
		if reference.start_with?('#')
			contained_id = reference[1..-1]
			@tScript.contained.find { |r| r.id == contained_id }
		elsif reference.start_with?('http')
			raise "Remote references not supported: #{reference}"
			return nil
		else 
			filepath = File.expand_path reference, File.dirname(File.absolute_path(@tScript.url))
      return nil unless File.exist? filepath
      file = File.open(filepath, 'r:UTF-8', &:read)
      file.encode!('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
      file = preprocess(file) if file.include?('${')
      FHIR.from_contents(file)
		end 
	end 

	# TODO: Figure out when reprocess would be called and whether or not it's
	# 		  important to include at this stage
	def preprocess
	end
	# Creating singleton instance methods for the BaseTestScript object, where 
	# each methods' name is a test.name/id and calling each method processes that
# 	# test. 

	def load_setup
		define_singleton_method :setup do
			return execute_autocreate, organize_setup
		end 
	end 

	def execute_autocreate
		actions = []
		@autocreate.each do |fixture_id|
			response = @client.create @fixtures[fixture_id]
			@id_map[fixture_id] = response.id
			actions << FHIR::TestReport::Setup::Action.new({
				'operation' => {
					'result' => ( response.code.include?([200, 201]) ? 'pass' : 'fail' ),
					'message' => "Autocreate Fixture #{fixture_id}"
				}
			})
			if response.code.include?([200, 201])
				FHIR.logger.error "Error processing Autocreate #{fixture_id}: Skipping Fixture"  
				break
			end 
		end 
		actions
	end 

	def organize_setup 
		group_by_action = @tScript.setup.action.chunk { |a| !a.operation.nil? }.map { |bool, val| val }
		faux_tests = group_by_action.each_slice(2).map { |op, assert| [op, assert].flatten }
		report = FHIR::TestReport::Setup.new
		for group in faux_tests
			group.define_singleton_method :action, -> { group } 
			group.define_singleton_method :id, -> { 'Setup' }
			process_test(group)
		end 
	end 

	def load_tests
		@tScript.test.each do |test|

			executable = "#{test.name} #{test.id} test".downcase.tr(' -', '_').to_sym
			define_singleton_method executable, -> { process_test(test) }
			@executables << executable
		end 
	end 

	def process_test(test)

		result = FHIR::TestReport::Test.new({
			'name' => test.id,
			'description' => test.description,
			'action' => []
		})

		begin
			skip = false
			test.action.each do |action| 
				unless skip
					result.action << perform_action(action)
					skip = assertion_failed?(result.action.last, test.id)
				else 
					result.action << skip_action(action)
				end 
			end 

		rescue => e
			@report.status = 'error'
			FHIR.logger.error "Fatal Error processing TestScript #{test.id} Action: #{e.message}\n#{e.backtrace}"
		end
		result
	end

	def skip_action(action)
		skipped_action = FHIR::TestReport::Setup::Action.new

		if action.assert
			skipped_assert = FHIR::TestReport::Setup::Action::Assert.new
			skipped_assert.result = 'skip'
			skipped_assert.message = action.assert.description
			skipped_action.assert = skipped_assert
		elsif action.operation
			skipped_operation = FHIR::TestReport::Setup::Action::Operation.new
			skipped_operation.result = 'skip'
			skipped_operation.message = action.operation.description
			skipped_action.operation = skipped_assert
		end 

		skipped_action
	end 

	def assertion_failed?(action, test_id)
		# May Also fail on test setup. 
		if action.nil? || (action.assert && ['fail', 'error'].include?(action.assert.result))
			FHIR.logger.error "[.assertion_failed?] Assertion failed during action #{test_id}: Proceeding to next action."  
			@report.result = 'fail'
			return true 
		end 
		return false
	end

	# Returns a FHIR::TestReport::Setup::Action
	# containing either a FHIR::TestReport::Setup::Action::Operation
	#                or a FHIR::TestReport::Setup::Action::Assert
	def perform_action(action)
		result = FHIR::TestReport::Setup::Action.new
		if action.operation
			result.operation = execute_operation(action.operation)
		elsif action.assert
			result.assert = handle_assertion(action.assert)
		end
		result
	end

	# TODO: Implement 'empty' case. Additionally, add error checking. When and where should this cause an error? 
	# TODO: LONG-TERM --- Add support for all possible codes.






	def execute_operation(operation)
		result = FHIR::TestReport::Setup::Action::Operation.new({
			'result' => 'pass',
			'message' => (operation.try(:description) || 'Unspecified description.')
			})

		unless operation.is_a?(FHIR::TestScript::Setup::Action::Operation)
			result.result = 'fail'
			result.message = '[.execute_operation] Received invalid operation: can not execute.'
			FHIR.logger.warn result.message
			return result
		end 

		requestHeaders = Hash[operation.requestHeader.map { |header| [header.field, header.value]}]
		format = FORMAT_MAP[operation.contentType || operation.accept]
		operation_code = operation.type.nil? ? 'empty' : operation.type.code 

		begin
			case operation_code
			when 'read'
				if operation.targetId
					@client.read @fixtures[operation.targetId].class, @id_map[operation.targetId], format
				elsif operation.url 
					# @client.get replace_variables(operation.url)
				else
					resource_type = replace_variables(operation.resource)
					resource_id = replace_variables(operation.params)
					@client.read "FHIR::#{resource_type}".constantize, id_from_path(resource_id), format
				end 



			when 'update','updateCreate'
				target_id = nil
				target_id = id_from_path(replace_variables(operation.params)) unless operation.params.nil? 
				target_id = @id_map[operation.targetId] unless operation.targetId.nil? || target_id

				fixture = @fixtures[operation.sourceId]
				id = replace_variables(target_id) #TODO -- Does not make sense
				fixture.id = id if fixture.id.nil? 

				@last_reply = @client.update fixture, id, format
			when 'delete'
				if operation.targetId.nil?
					params = replace_variables(operation.params)
					# TODO: This flows really weirdly and doesn't feel clean.
					if params == '/'
						result.result = 'error'
						result.message = 'Unable to delete: no id given.'
						return result 
					end 
					@last_reply = @client.destroy "FHIR::#{operation.resource}".constantize, nil, params: params
				else
					@last_reply = @client.destroy @fixtures[operation.targetId].class, @id_map[operation.targetId]
				end
			when 'empty'
				FHIR.logger.warn '[.execute_operation] Received operation with inactionable code type.'
				return result
			else 
				result.result = 'error'
				result.message = "Undefined operation #{operation.type.to_json}"
				FHIR.logger.error(result.message)
			end 
			result.result = judge_response(operation_code)
			handle_response(operation) 
		rescue => e
			result.result = 'error'
			result.message = "Error while executing #{operation.label} operation."
			FHIR.logger.error result.message 
		end 
		result
	end 

	
	def judge_response(operation)
		@last_reply = @client.reply

		case operation
		when 'read'
			return 'fail' unless @last_reply.response[:code] == 200
		end 
		return 'pass'
	end 


	def handle_response(operation)

		return unless operation.responseId && operation.type.code != 'delete'

		begin
			FHIR.logger.info "Overwriting response #{operation.responseId}..." if @response_map.keys.include?(operation.responseId)
			FHIR.logger.info "Storing response #{operation.responseId}..."
			@response_map[operation.responseId] = @client.reply.response
		rescue => e
			
		end
	end 

	def handle_assertion(assertion)

		result = FHIR::TestReport::Setup::Action::Assert.new({
			'result' => 'pass',
			'message' => assertion.label || assertion.description
		})

		operator = assertion.operator.nil? ? :equals : assertion.operator.to_sym
		warningOnly = assertion.warningOnly.nil? ? false : assertion.warningOnly

		begin
			case 
			when assertion.contentType 
				call_assertion(:assert_contentType, @last_reply, assert_contentType)	
			when assertion.headerField
				if assertion.direction == 'request'
					header_value = @last_reply.request[:headers][assertion.headerField]
					msg_prefix = 'Request'
				else
					header_value = @last_reply.response[:headers][assertion.headerField.downcase]
					msg_prefix = 'Response'
				end 
				call_assertion(:assert_operator, header_value, operator, replace_variables(assertion.value), "#{msg_prefix} Header field #{assertion.headerField}")
			when assertion.minimumId
				call_assertion(:assert_minimum, @last_reply, @fixtures[assertion.minimumId])
			when assertion.navigationLinks
				call_assertion(:assert_navigation_links, @last_reply)
			when assertion.requestURL
				call_assertion(:assert_operator, @last_link.request[:url], operator, replace_variables(assertion.requestURL))
			when assertion.path
				id = assertion.sourceId
				compId = assertion.compareToSourceId
				path = assertion.path

				resource = id ? find_resource(id) : pull_resource(@last_reply)
				actual = extract_value_by_path(resource, path)
				expected = compId ? extract_value_by_path(find_resource(compId), path) : replace_variables(assertion.value)

				call_assertion(:assert_operator, actual, operator, expected)
			when assertion.compareToSourcePath 
				compId = assertion.compareToSourceId
				path = assertion.compareToSourcePath

				if assertion.sourceId
					resource = find_resource(assertion.sourceId)
				else 
					raise AssertionException.new("compareToSourcePath requires sourceId: #{assertion.to_json}")
				end

				actual = extract_value_by_path(resource, assertion.compareToSourcePath)
				expected = compId ? extract_value_by_path(find_resource(compId), path) : replace_variables(assertion.value)

				call_assertion(:assert_operator, actual, operator, expected)
			when assertion.resource
				call_assertion(:assert_resource_type, @last_reply, "FHIR::#{assertion.resource}".constantize)
			when assertion.responseCode
				call_assertion(:assert_operator, @last_reply.response[:code].to_s, operator, assertion.responseCode)
			when assertion.response
				call_assertion(:assert_response_code, @last_reply, CODE_MAP[assertion.response])
			when assertion.validateProfileId
				# TODO: What is this doing?
				profile_uri = @tScript.profile.first { |p| p.id = assertion.validateProfileId}.reference
				reply = @client.validate(@last_reply.resource,{profile_uri: profile_uri})
				call_assertion(:assert_valid_profile, reply.response, @last_reply.resource.class)
			when assertion.expression
				id = assertion.sourceId
				resource = id ? find_resource(id) : pull_resource(@last_reply)

				begin
					unless FluentPath.evaluate(assertion.expression, resource.to_hash)
						raise AssertionException.new("Expression did not evaluate to true: #{assertion.expression}", assertion.expression)
          end
				rescue => fpe
					raise "Invalid Expression: #{assertion.expression}"
				end
			when assertion.compareToSourceExpression
				if assertion.sourceId 
					find_resource(assertion.sourceId) 
				else
					raise AssertionException.new("compareToSourceExpression requires sourceId: #{assertion.to_json}")
				end 

				begin
					unless FluentPath.evaluate(assertion.compareToSourceExpression, resource.to_hash)
						raise AssertionException.new("Expression did not evaluate to true: #{assertion.compareToSourceExpression}", assertion.compareToSourceExpression)
					end
				rescue => fpe
					raise "Invalid Expression: #{assertion.compareToSourceExpression}"
				end
			else
				result.result = 'error'
				result.message = "Unhandled Assertion: #{assertion.to_json}"
			end 
		rescue AssertionException => ae
			result.result = 'fail'
			result.result = 'warning' if warningOnly #TODO: Is this right?
			result.message = ae.message
		rescue => e
			#TODO: Document the test id and return that here.
			FHIR.logger.error "Unable to process assertion."
			result.result = 'error'
			result.message = "#{'Assertion unable to be processed.'}"
		end
		result 
	end 

	def call_assertion(method, *params)
		FHIR.logger.debug "Assertion: #{method}"
		self.method(method).call(*params)
	end 

	# Search for the variable denoted via input, then extract that variable's 
	# value either from the header or body of an existing response. If body
	# extraction, use the var.path element to search. If none of these value 
	#	extraction strategies are viable, then return value as ''. Additionally,
	# warn if any unknown variables are included in the input.
	def replace_variables(input)
		return input unless input && input.include?('${') 

		@tScript.variable.each do |var|
			if input.include? "${#{var.name}}"

				variable_value = nil
				value_source = @response_map[var.sourceId]

				if var.headerField && value_source
					headers = value_source.response[:headers] 
					variable_value = headers.find { |key,value| value if key.downcase == var.headerField.downcase }

				elsif var.path
					resource = value_source ? FHIR.from_contents(value_source.body) : @fixtures[var.sourceId]
					FHIR.logger.error "Value not found for variable: #{var.sourceId}. Skipping Test." if resource.nil?
					variable_value = extract_value_by_path(resource, var.path)
				end 

				variable_value = var.defaultValue || '' unless variable_value
				input.gsub!("${#{var.name}}", variable_value)
			end
		end 

		if input.include? '${'
			unknown_variables = input.scan(/(\$\{)([A-Za-z0-9\_]+)(\})/).map { |x| x[1] }
			FHIR.logger.warn "Unknown variables: #{unknown_variables.join(', ')}"
		end
		input
	end 

	# TODO: Error catching/throwing
	# Attempt to extract the value that exists at the end of the path in the 
	# given resource. Check for errors in either XML (defualt) or JSON attempt.
	def extract_value_by_path(resource, path)
		begin
			value = extract_xpath_value(resource.to_xml, path) 
		rescue 
			value = JsonPath.new(path).first(resource.to_json)
			FHIR.logger.error "Unable to extract variable in either XML or JSON format. Skipping Test." unless value 
		end
		return value || ''
	end 

	# Use the XML format to extract the value by path. 
	def extract_xpath_value(resource_xml, resource_xpath)
		begin 
			# Massage the xpath if it doesn't have fhir: namespace or if doesn't end in @value
			# Also make it look in the entire xml document instead of just starting at the root
			xpath = resource_xpath.split("/").map{|s| if s.starts_with?('fhir:') || s.length == 0 || s.starts_with?('@') then s else "fhir:#{s}" end}.join('/')
			xpath = "#{xpath}/@value" unless xpath.ends_with? '@value'
			xpath = "//#{xpath}"

			resource_doc = Nokogiri::XML(resource_xml)
			resource_doc.root.add_namespace_definition('fhir', 'http://hl7.org/fhir')
			resource_element = resource_doc.xpath(xpath)

			# This doesn't work on warningOnly; consider putting back in place
			# raise AssertionException.new("[#{resource_xpath}] resolved to multiple values instead of a single value", resource_element.to_s) if resource_element.length>1
			resource_element.first.try(:value)
			rescue
				FHIR.logger.warn "Error extracting #{resource_xpath} from xml-formatted resource"
				return nil
			end 
	end 

	# TODO: What's the value in having a seperate method for this?
	def id_from_path(path)
		path[1..-1]
	end 
end 










