# frozen_string_literal: true
require 'securerandom'

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
    @builder_template ||= TestReportBuilder.new(script, bound_variables)
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

  # A 'bound_variables' method ought to be defined in the klass
  # that includes the handler - if 'bound_variables' is undefined,
  # this feeds an empty hash to the builder
  def bound_variables
    begin
      super
    rescue NoMethodError
      {}
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

    def initialize(testscript_blueprint = nil, bound_variables = {})
      add_boilerplate(testscript_blueprint)
      add_input_extensions(testscript_blueprint, bound_variables)
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

    def add_input_extensions(setup_blueprint, bound_variables)
      return unless setup_blueprint

      # if any variables have a defaultValue defined
      # and have been bound
      # then add an extension with the input value

      setup_blueprint.variable.each { |script_variable|
        if (script_variable.defaultValue != nil)
          
          if (bound_variables[script_variable.name] != nil)
            input_ext = FHIR::Extension.new()
            input_ext.url = "https://fhir-crucible.github.io/testscript-engine-ig/StructureDefinition/dynamic-input"
            input_ext_variable = FHIR::Extension.new()
            input_ext_variable.url = "variableName"
            input_ext_variable.valueString = script_variable.name
            input_ext.extension << input_ext_variable
            input_ext_value = FHIR::Extension.new()
            input_ext_value.url = "value"
            input_ext_value.valueString = bound_variables[script_variable.name]
            input_ext.extension << input_ext_value
            report.extension << input_ext
          end
        
        end

      }
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
      report.id = SecureRandom.uuid
      report.name = "TestReport for " + testscript_blueprint.name
      report.testScript = FHIR::Reference.new({
        reference: testscript_blueprint.url,
        type: "TestScript",
        display: testscript_blueprint.name
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

    def self.get_testreport_inputs_string(test_report)
      inputs_string = ""
      
      report.extension.each { |one_ext| 
        if (one_ext.url == "https://fhir-crucible.github.io/testscript-engine-ig/StructureDefinition/dynamic-input")
          variable_name_ext = one_ext.extension.find { |one_sub_ext| one_sub_ext.url == "variableName" }
          variable_value_ext = one_ext.extension.find { |one_sub_ext| one_sub_ext.url == "value" }
          if (variable_name_ext && variable_value_ext)
            inputs_string = "#{inputs_string}#{"; " unless inputs_string == ""}#{variable_name_ext.valueString}=#{variable_value_ext.valueString}"
          end
        end
      }

      return inputs_string
    end


  end

  def self.get_testreport_inputs_string(test_report)
    inputs_string = ""
    
    test_report.extension.each { |one_ext| 
      if (one_ext.url == "https://fhir-crucible.github.io/testscript-engine-ig/StructureDefinition/dynamic-input")
        variable_name_ext = one_ext.extension.find { |one_sub_ext| one_sub_ext.url == "variableName" }
        variable_value_ext = one_ext.extension.find { |one_sub_ext| one_sub_ext.url == "value" }
        if (variable_name_ext && variable_value_ext)
          inputs_string = "#{inputs_string}#{"; " unless inputs_string == ""}#{variable_name_ext.valueString}=#{variable_value_ext.valueString}"
        end
      end
    }

    return inputs_string
  end


  def self.add_testreport_executed_as_subtest_ext(test_report, subtest_execution)
    subtest_ext = FHIR::Extension.new()
    subtest_ext.url = "https://fhir-crucible.github.io/testscript-engine-ig/StructureDefinition/executed-as-subtest"
    subtest_ext.valueBoolean = subtest_execution
    test_report.extension << subtest_ext
  end

  def self.add_testreport_must_pass_ext(test_report, must_pass)
    subtest_must_pass_ext = FHIR::Extension.new()
    subtest_must_pass_ext.url = "https://fhir-crucible.github.io/testscript-engine-ig/StructureDefinition/executed-as-subtest-must-pass"
    subtest_must_pass_ext.valueBoolean = must_pass
    test_report.extension << subtest_must_pass_ext
  end

  def self.testreport_executed_as_subtest?(test_report)
    test_report.extension.reduce(false) { |ag, one_ext| 
      if one_ext.url == "https://fhir-crucible.github.io/testscript-engine-ig/StructureDefinition/executed-as-subtest" 
        one_ext.valueBoolean
      else 
        ag
      end
    }
  end

  def self.testreport_must_pass?(test_report)
    test_report.extension.reduce(true) { |ag, one_ext| 
      if one_ext.url == "https://fhir-crucible.github.io/testscript-engine-ig/StructureDefinition/executed-as-subtest-must-pass" 
        one_ext.valueBoolean
      else 
        ag
      end
    }
  end

end