# frozen_string_literal: true
require 'pry-nav'
require 'fhir_client'

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                                                               #
#                           TestReportHandler Module                            #
#                                                                               #
# The TestReportHandler (handler) module is intended to be imported into the    #
# TestScriptRunnable (runnable) class. The handler instantiates a               #
# TestReportBuilder (builder) object tailored to the parent runnable instance.  #
# In executing a runnable, calls (i.e. 'Pass', 'Fail') are made to the handler  #
# module -- which then directs the builder instance to update its report        #
# accordingly. Each time the runnable is executed, it instantiates a new        #
# builder instance is instantiated, using the initial builder as a template.    #                                                              #
#                                                                               #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

module TestReportHandler
  def self.included(klass)
    def testreport
      testreport_builder.report
    end

    def fresh_testreport
      @testreport_builder = nil
    end

    def testreport_builder
      @testreport_builder ||= fresh_testreport_builder
    end

    def fresh_testreport_builder
      testreport_builder_template.deep_clone
    end

    def testreport_builder_template
      @testreport_builder_template ||= TestReportBuilder.new
    end

    def pass
      testreport_builder.pass
    end

    def skip(message = nil)
      testreport_builder.skip(message)
    end

    def warning(message = nil)
      testreport_builder.skip(message)
    end

    def fail(message = nil)
      testreport_builder.skip(message)
    end
  end

  class TestReportBuilder
    def self.build_report(script)
      builder = new
      builder.build_report_outline(script)
      builder
    end

    def deep_clone
      builder_deep_clone = self.class.new
      builder_deep_clone.cloning_in_progress(true)
      builder_deep_clone.store_base_actions(base_actions.deep_dup)
      builder_deep_clone.build_report_outline(script)
      builder_deep_clone.cloning_in_progress(false)
    end

    def cloning_in_progress(cloning_state = nil)
      @cloning_in_progress = cloning_state if cloning_state
      @cloning_in_progress ||= false
    end

    def cloning_in_progress?
      cloning_in_progress
    end

    def report_outline
      @report_outline ||= FHIR::TestScript.new
    end

    def report
      @report ||= report_outline
    end

    def store_base_actions(base_action)
      base_actions.concat(Array(base_action))
    end

    def next_base_action
      base_actions.shift
      finalize_report if base_actions.empty?
      return
    end

    def base_actions
      @base_actions ||= []
    end

    def base_action
      @base_action.first
    end

    def build_setup_outline(setup)
      return unless setup

      setup_actions = setup.action.map do |action|
        operation, assert = build_base_action_outline(action)
        FHIR::TestReport::Setup::Action.new(operation: operation, assert: assert)
      end

      report_outline.setup = FHIR::TestReport::Setup.new(action: setup_actions)
    end

    def build_test_outline(tests)
      return if tests.empty?

      report_outline.test = tests.map do |test|
        actions = test.action.map do |action|
          operation, assert = build_base_action_outline(action)
          FHIR::TestReport::Test::Action.new(id: action.id, operation: operation, assert: assert)
        end

        FHIR::TestReport::Test.new(action: actions)
      end
    end

    def build_teardown_outline(teardown)
      return unless teardown

      teardown_actions = teardown.action.map do |action|
        operation, assert = build_base_action_outline(action)
        FHIR::TestReport::Teardown::Action.new(operation: operation)
      end

      report_outline.teardown = FHIR::TestReport::Teardown.new(action: teardown_actions)
    end

    def build_base_action_outline(action)
      operation = build_operation_outline(action.operation)
      assert = action.respond_to?(:assert) ? build_assert_outline(action.assert) : nil

      return operation, assert
    end

    def build_operation_outline(operation)
      return unless operation

      if cloning_in_progress
        operation = base_action
        next_base_action
        return operation
      end

      operation = FHIR::TestReport::Setup::Action::Operation.new({
        id: operation.label || operation.id,
        message: operation.description
      })

      store_base_actions(operation)
      operation
    end

    def build_assert_outline(assert)
      return unless assert

      if cloning_in_progress
        operation = base_action
        next_base_action
        return operation
      end

      assert = FHIR::TestReport::Setup::Action::Assert.new({
        id: assert.label || assert.id,
        message: assert.description
      })

      store_base_actions(assert)
      assert
    end

    def add_boilerplate(script)
      report.name = script.name.gsub(/(?i)testscript/, 'TestReport')
      report.id = script.id.gsub(/(?i)testscript/, 'testreport')
      report.tester = 'The MITRE Corporation'
      report.testScript = script.url
      report.status = 'in-progress'
      report.result = 'pending'
      report
    end

    def finalize_report
      report
    end

    def pass
      base_action.result = 'pass'
      next_base_action
    end

    def skip(message = nil)
      base_action.result = 'skip'
      base_action.message = message if message
      next_base_action
    end

    def warning
      base_action.result = 'warning'
      base_action.message = message if message
      next_base_action
    end

    def fail
      base_action.result = 'fail'
      base_action.message = message if message
      next_base_action
    end
  end
end