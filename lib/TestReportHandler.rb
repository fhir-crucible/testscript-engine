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
  end

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

#   # <--- ---> #
#  In the builder, the script maintained within the parent runnable is called
#  and each of its phases -- setup, test, and teardown -- are processed in order
#  to outline the testreport that will result from running the script. This can be doesn
#  as any action within the script must have a corresponding action within the report.

  class TestReportBuilder
    def report
      @report ||= FHIR::TestReport.new
    end

    def action
      actions.first
    end

    def actions
      @actions ||= []
    end

    def store_action(action)
      actions.concat(Array(action))
    end

    def next_action
      actions.shift
      finalize_report if actions.empty?
    end

    def initialize(actions_for_report = [])
      # use_existing_actions(actions_for_report)
      report.setup = outline_setup(script.setup)
      report.test = outline_test(script.test)
      report.teardown = outline_teardown(script.teardown)

      @fail_count = 0
      @action_count = actions.length
    end

    # def user_existing_actions(actions_for_report)
    #   return if actions_for_report.empty?
    # end

    # # def deep_clone
    # #   builder_deep_clone = self.class.new
    # #   builder_deep_clone.cloning_in_progress(true)
    # #   builder_deep_clone.store_base_actions(base_actions.deep_dup)
    # #   builder_deep_clone.build_report_outline(script)
    # #   builder_deep_clone.cloning_in_progress(false)
    # # end

    # # def cloning_in_progress(cloning_state = nil)
    # #   @cloning_in_progress = cloning_state if cloning_state
    # #   @cloning_in_progress ||= false
    # # end

    # # def cloning_in_progress?
    # #   cloning_in_progress
    # # end

    def outline_setup(setup)
      return unless setup

      setup_actions = setup.action.map { |action| outline_action(action) }

      FHIR::TestReport::Setup.new(action: setup_actions)
    end

    def outline_test(tests)
      return if tests.empty?

      tests.map do |test|
        actions = test.action.map { |action| outline_action(action) }
        FHIR::TestReport::Test.new(action: actions)
      end
    end

    def outline_teardown(teardown)
      return unless teardown

      teardown_actions = teardown.action.map { |action| outline_action(action) }

      FHIR::TestReport::Teardown.new(action: teardown_actions)
    end

    def outline_action(action)
      action_type = action.class.to_s.split("::")[2]

      "FHIR::TestReport::#{action_type}::Action".constantize.new({
        id: action.id,
        operation: outline_operation(action.operation),
        assert: (outline_assert(action.assert) unless action_type == 'Teardown')
      })
    end

    def outline_operation(operation)
      return unless operation

      operation = FHIR::TestReport::Setup::Action::Operation.new({
        id: operation.label || operation.id,
        message: operation.description
      })

      store_action(operation)
      operation
    end

    def outline_assert(assert)
      return unless assert

      assert = FHIR::TestReport::Setup::Action::Assert.new({
        id: assert.label || assert.id,
        message: assert.description
      })

      store_action(assert)
      assert
    end

    def add_boilerplate
      report.name = script.name&.gsub(/(?i)testscript/, 'TestReport')
      report.id = script.id&.gsub(/(?i)testscript/, 'testreport')
      report.tester = 'The MITRE Corporation'
      report.testScript = script.url
      report.status = 'in-progress'
      report.result = 'pending'
    end

    def finalize_report
      report.status = 'completed'
      report.result = (@fail_count == 0 ? 'pass' : 'fail')
      report.score = (@fail_count.to_f / @action_count).round(2)
      report.issued = Time.now
    end

    def pass
      action.result = 'pass'
      next_action
    end

    def skip(message = nil)
      action.result = 'skip'
      action.message = message if message
      next_action
    end

    def warning(message = nil)
      action.result = 'warning'
      action.message = message if message
      next_action
    end

    def fail(message = nil)
      action.result = 'fail'
      action.message = message if message
      @fail_count += 1
      next_action
    end
  end
end