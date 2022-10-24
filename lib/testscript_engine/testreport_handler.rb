# frozen_string_literal: true

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                                                               #
#                           TestReportHandler Module                            #
#                                                                               #
# The TestReportHandler (handler) module is intended to be imported into the    #
# TestScriptRunnable (runnable) class. The handler instantiates a               #
# TestReportBuilder (builder) object tailored to the parent runnable instance.  #
# In executing a runnable, calls (i.e. 'Pass', 'Fail') are made to the handler  #
# module -- which then directs the builder instance to update its report        #
# accordingly. Think of the handler as the 'API' to interact with the           #
# TestReport output by the execution of a runnable. Each time the runnable is   #
# executed, it instantiates a new builder instance, using the initial builder   #
# as a template.                                                                #
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
    @builder_template ||= TestReportBuilder.new(script)
  end

  # TODO: Remove!
  def pass(message = nil)
    report_builder.pass
  end

  def fail(message = nil)
    report_builder.fail(message)
  end

  def skip(message = nil)
    report_builder.skip(message)
  end

  def warning(message = nil)
    report_builder.warning(message)
  end

  def error(message = nil)
    report_builder.error(message)
  end

  def finalize_report
    report_builder.finalize_report
    testreport
  end

  def cascade_skips(number_to_skip)
     while number_to_skip > 0
      report_builder.skip
      number_to_skip -= 1
    end
  end

  # A 'script' method ought to be defined in the klass
  # that includes the handler - if 'script' is undefined,
  # this feeds an empty testscript to the builder
  def script
    begin
      super
    rescue NoMethodError
      FHIR::TestScript.new
    end
  end

  class TestReportBuilder
    attr_accessor :pass_count, :total_test_count, :actions

    def actions
      @actions ||= []
    end

    def report
      @report ||= FHIR::TestReport.new
    end

    def initialize(testscript_blueprint = nil)
      add_boilerplate(testscript_blueprint)
      build_setup(testscript_blueprint.setup)
      build_test(testscript_blueprint.test)
      build_teardown(testscript_blueprint.teardown)

      self.pass_count = 0
      self.total_test_count = actions.length
    end

    def build_setup(setup_blueprint)
      return unless setup_blueprint

      actions = setup_blueprint.action.map { |action| build_action(action) }
      report.setup = FHIR::TestReport::Setup.new(action: actions)
    end

    def build_test(test_blueprint)
      return if test_blueprint.empty?

      report.test = test_blueprint.map do |test|
        actions = test.action.map { |action| build_action(action) }
        FHIR::TestReport::Test.new(action: actions)
      end
    end

    def build_teardown(teardown_blueprint)
      return unless teardown_blueprint

      actions = teardown_blueprint.action.map { |action| build_action(action) }
      report.teardown = FHIR::TestReport::Teardown.new(action: actions)
    end

    def build_action(action_blueprint)
      phase = action_blueprint.class.to_s.split("::")[2]

      action_definition = {
        id: action_blueprint.id,
        operation: build_operation(action_blueprint.operation),
        assert: (build_assert(action_blueprint.assert) unless phase == 'Teardown')
      }

      "FHIR::TestReport::#{phase}::Action".constantize.new(action_definition)
    end

    def build_operation(operation_blueprint)
      return unless operation_blueprint

      operation_def = {
        id: operation_blueprint.label || operation_blueprint.id || 'unlabeled operation',
        message: operation_blueprint.description
      }

      operation = FHIR::TestReport::Setup::Action::Operation.new(operation_def)
      store_action(operation)
      operation
    end

    def build_assert(assert_blueprint)
      return unless assert_blueprint

      assert_def = {
        id: assert_blueprint.label || assert_blueprint.id || 'unlabeled assert',
        message: assert_blueprint.description
      }

      assert = FHIR::TestReport::Setup::Action::Assert.new(assert_def)
      store_action(assert)
      assert
    end

    def add_boilerplate(testscript_blueprint)
      report.result = 'pending'
      report.status = 'in-progress'
      report.tester = 'The MITRE Corporation'
      report.id = testscript_blueprint.id&.gsub(/(?i)testscript/, 'testreport')
      report.name = testscript_blueprint.name&.gsub(/(?i)testscript/, 'testreport')
      report.testScript = FHIR::Reference.new({
        reference: testscript_blueprint.url,
        type: "http://hl7.org/fhir/R4B/testscript.html"
      })
    end

    def finalize_report
      report.issued = DateTime.now.to_s
      report.status = 'completed'
      report.score = (self.pass_count.to_f / self.total_test_count).round(2) * 100
      report.result = (report.score == 100.0 ? 'pass' : 'fail')
    end

    def action
      actions.first
    end

    def store_action(action)
      actions.concat(Array(action))
    end

    def next_action
      actions.shift
      finalize_report if actions.empty?
    end

    def pass
      action.result = 'pass'
      self.pass_count += 1
      next_action
    end

    def skip(message = nil)
      action.result = 'skip'
      action.message = message if message
      self.total_test_count -= 1
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
      next_action
    end

    def error(message = nil)
      action.result = 'error'
      action.message = message if message
      next_action
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
  end
end