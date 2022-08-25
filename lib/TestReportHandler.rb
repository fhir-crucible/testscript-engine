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

  def testreport
    report_builder.report
  end

  def fresh_testreport
    @report_builder = nil
  end

  def report_builder
    @report_builder ||= fresh_builder
  end

  def fresh_builder
    builder_template.clone
  end

  def builder_template
    @builder_template ||= TestReportBuilder.new
  end

  def pass
    report_builder.pass
  end

  def skip(message = nil)
    report_builder.skip(message)
  end

  def warning(message = nil)
    report_builder.warning(message)
  end

  def fail(message = nil)
    report_builder.fail(message)
  end

  def script
    begin
      super
    rescue NoMethodError
      FHIR::TestScript.new
    end
  end

#   # <--- ---> #
#  In the builder, the script maintained within the parent runnable is called
#  and each of its phases -- setup, test, and teardown -- are processed in order
#  to outline the testreport that will result from running the script. This can be doesn
#  as any action within the script must have a corresponding action within the report.

  class TestReportBuilder
    attr_accessor :fail_count, :action_count

    def action
      actions.first
    end

    def actions
      @actions ||= []
    end

    def store_action(action)
      actions.concat(Array(action))
    end

    def report
      @report ||= FHIR::TestReport.new
    end

    def next_action
      actions.shift
      finalize_report if actions.empty?
    end

    def increment_fail_count
      self.fail_count += 1
    end

    def clone
      builder_dup = self.deep_dup
      builder_dup.actions.clear
      builder_dup.instance_eval('@report = FHIR::TestReport.new(self.report.to_hash)')

      clone_actions(builder_dup.report.setup, builder_dup)
      builder_dup.report.test.each { |test| clone_actions(test, builder_dup) }
      clone_actions(builder_dup.report.teardown, builder_dup)

      builder_dup
    end

    def clone_actions(report_phase, clone)
      report_phase.try(:action)&.each do |action|
        clone.store_action(action.operation || action.assert)
      end
    end

    def initialize
      report.setup = outline_setup(script.setup)
      report.test = outline_test(script.test)
      report.teardown = outline_teardown(script.teardown)

      self.action_count = actions.length
      self.fail_count = 0
    end

    def outline_setup(setup)
      return unless setup

      FHIR::TestReport::Setup.new({
        action: setup.action.map { |action| outline_action(action) }
      })
    end

    def outline_test(tests)
      return if tests.empty?

      tests.map do |test|
        FHIR::TestReport::Test.new({
          action: test.action.map { |action| outline_action(action) }
        })
      end
    end

    def outline_teardown(teardown)
      return unless teardown

      FHIR::TestReport::Teardown.new({
        action: teardown.action.map { |action| outline_action(action) }
      })
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
      report.result = 'pending'
      report.status = 'in-progress'
      report.testScript = script.url
      report.tester = 'The MITRE Corporation'
      report.id = script.id&.gsub(/(?i)testscript/, 'testreport')
      report.name = script.name&.gsub(/(?i)testscript/, 'TestReport')
    end

    def finalize_report
      report.issued = Time.now
      report.status = 'completed'
      report.result = (self.fail_count.zero? ? 'pass' : 'fail')
      report.score = (self.fail_count.to_f / self.action_count).round(2)
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
      increment_fail_count
      next_action
    end
  end
end