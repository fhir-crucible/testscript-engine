# frozen_string_literal: true
require_relative 'operation'
require_relative 'assertion'
require_relative 'message_handler'
require_relative 'testreport_handler'

class TestScriptRunnable
  include Operation
  include Assertion
  prepend MessageHandler
  include TestReportHandler

  attr_accessor :script, :client, :client_util, :reply, :get_fixture_block, :options, :available_profiles, :engine, :bound_variables

  def id_map
    @id_map ||= {}
  end

  def fixtures
    @fixtures ||= {}
  end

  def profiles
    @profiles ||= {}
  end

  def request_map
    @request_map ||= {}
  end

  def response_map
    @response_map ||= {}
  end

  def autocreate
    @autocreate ||= []
  end

  def autodelete_ids
    @autodelete_ids ||= []
  end

  def initialize(script, block, options, engine = nil, available_profiles = {}, bound_variables = {})
    self.get_fixture_block = block
    self.options = options
    self.client_util = FHIR::Client.new('')
    self.available_profiles = available_profiles
    self.engine = engine
    self.bound_variables = bound_variables
    @script = script
    load_fixtures
    load_profiles
  end

  def run(client)
    @client = client

    fresh_testreport

    preprocess
    setup
    test
    teardown
    postprocessing

    finalize_report
  end

  def preprocess
    return info(:no_preprocess) if autocreate.empty?
    autocreate.each do |fixture|
      begin
        client.send(*build_request((create_operation(fixture))))
      rescue => e
        error(:uncaught_error, e.message)
      end
    end
  end

  def setup
    return info(:no_setup) unless script.setup
    handle_actions(script.setup.action, :setup)
  end

  def test
    script.test.each { |test| handle_actions(test.action, :test) }
  end

  def teardown
    return info(:no_teardown) unless script.teardown
    handle_actions(script.teardown.action, :teardown)
  end

  def postprocessing
    @ended = nil
    @id_map = {}
    @request_map = {}
    @response_map = {}

    return info(:no_postprocess) if autocreate.empty?

    autodelete_ids.each do |fixture_id|
      begin
        client.send(*build_request((delete_operation(fixture_id))))
      rescue => e
        error(:uncaught_error, e.message)
      end
    end
  end

  def handle_actions(actions, section)
    @modify_report = true
    if @ended && section == :test
      abort_test(actions)
      @modify_report = false
      return
    end
    current_action = 0

    actions.each do |action|
      current_action += 1
      if action.operation
        begin
          execute(action.operation)
        rescue OperationException => oe
          error(oe.details)
          if section != :teardown
            @ended = true if section == :setup
            cascade_skips_with_message(actions, current_action) unless current_action == actions.length
          end
        rescue => e
          error(:uncaught_error, e.message)
          if section != :teardown
            @ended = true if section == :setup
            cascade_skips_with_message(actions, current_action) unless current_action == actions.length
          end
        end
      elsif action.respond_to?(:assert)
        begin
          evaluate(action.assert, options)
        rescue AssertionException => ae
          if ae.outcome == :skip
            skip(:eval_assert_result, ae.details)
          elsif ae.outcome == :fail
            next warning(:eval_assert_result, ae.details) if action.assert.warningOnly
            fail(:eval_assert_result, ae.details)
            if section == :setup
              # stop execution and go right to teardown (no remaining setup, no tests)
              @ended = true
              cascade_skips_with_message(actions, current_action) unless current_action == actions.length
              @modify_report = false
              return
            elsif section == :test
              # stop execution of this test and go to the next test
              cascade_skips_with_message(actions, current_action) unless current_action == actions.length
              @modify_report = false
              return
            else
              fail(:eval_assert_result, ae.details)
            end
          end
        rescue => e
          error(:uncaught_error, e.message)
          if section != :teardown
            @ended = true if section == :setup
            cascade_skips_with_message(actions, current_action) unless current_action == actions.length
            return
          end
        end
      end
    end


    @modify_report = false
  end

  def cascade_skips_with_message(actions, current_action)
    actions_to_skip = actions.slice(current_action, actions.length)
    cascade_skips(:skip_on_fail, actions_to_skip, actions_to_skip.length)
  end

  def abort_test(actions_to_skip)
    cascade_skips(:abort_test, actions_to_skip, 'setup', actions_to_skip.length)
  end

  def load_fixtures
    script.fixture.each do |fixture|
      next warning(:no_static_fixture_id) unless fixture.id
      next warning(:no_static_fixture_resource) unless fixture.resource

      resource = get_fixture_from_ref(fixture.resource)
      next unless resource

      fixtures[fixture.id] = resource
      autocreate << fixture.id if fixture.autocreate
      autodelete_ids << fixture.id if fixture.autodelete
    end
  end

  def load_profiles
    print_out " Loading script profiles..."
    script.profile.each do |profile|
      next warning(:no_static_profile_id) unless profile.id
      next warning(:no_static_profile_reference) unless profile.reference

      if available_profiles[profile.reference] == nil
        # try to get the structure definition from the url
        response = client_util.send(:get, profile.reference, { 'Content-Type' => 'json' })
        if !response.response[:code].to_s.starts_with?('2')
          print_out "  -> Failed to load profile StructureDefinition from '#{profile.reference}': Response code #{response.response[:code]}"
          raise "profile load failed"
        end
        profile_def = FHIR.from_contents(response.response[:body].to_s)
        profiles[profile.id] = profile_def
        if options["ext_validator"] != nil 
          print_out  "  Adding '#{profile_def.url}' to external validator"
          reply = client_util.send(:post, options["ext_validator"]+"/profiles", profile_def, { 'Content-Type' => 'json' })
  
          if reply.response[:code].start_with?("2")
            print_out  "  -> Success! Added '#{profile_def.url}' to External validator."
          else
            raise "validator profile load failed"
          end
        end
        info(:loaded_remote_profile, profile.reference, profile.reference)
      else
        profiles[profile.id] = available_profiles[profile.reference]
      end
    end
  end

  def get_fixture_from_ref(reference)
    return warning(:bad_reference) unless reference.is_a?(FHIR::Reference)

    ref = reference.reference
    return warning(:no_reference) unless ref

    if ref.start_with? 'http'
      response = client_util.send(:get, ref, { 'Content-Type' => 'json' })

      if response.response[:code].to_s.starts_with?('2')
        info(:added_remote_fixture, ref)
        return FHIR.from_contents(response.response[:body].to_s)
      else
        warning(:missed_remote_fixture, ref)
      end
    end

    if ref.start_with? '#'
      contained = script.contained.find { |r| r.id == ref[1..] }
      return contained || warning(:no_contained_resource, ref)
    end

    ref.gsub!('fixtures/', "")
    fixture = get_fixture_block.call(ref)
    fixture ? info(:added_fixture, ref) : warning(:missed_fixture, ref)
    fixture
  end

  def storage(op)
    @reply = client.reply
    reply.nil? ? return : client.reply = nil

    request_map[op.requestId] = reply.request if op.requestId
    response_map[op.responseId] = reply.response if op.responseId

    (reply.resource = FHIR.from_contents(reply.response&.[](:body).to_s)) rescue {}
    (reply.response[:body] = reply.resource)
    response_map[op.responseId][:body] = reply.resource if reply.resource and response_map[op.responseId]

    if op.targetId and (reply.request[:method] == :delete) and [200, 201, 204].include?(reply.response[:code])
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
      headers&.find { |h, v| h == var.headerField || h == var.headerField.downcase }&.last
    elsif bound_variables[var.name] != nil
      bound_variables[var.name]
    end || var.defaultValue
  end

  def evaluate_expression(expression, resource)
    return unless expression and resource

    if options["ext_fhirpath"]
      path = options["ext_fhirpath"] + "/evaluate?path=#{expression}"
      reply = client_util.send(:post, path, resource, { 'Content-Type' => 'json' })
      
      if reply.response[:code].to_s.start_with? "2"
        result = JSON.parse(reply.response[:body].body)
        return result.map {|entry| entry["element"]}
      end
      print_out "External validator failed: " + reply.response[:code]

    else
      return begin
        FHIRPath.evaluate(expression, resource.to_hash)
      rescue RuntimeError => e
        return nil
      end
    end
  end
end
