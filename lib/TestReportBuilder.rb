# frozen_string_literal: true
require 'pry-nav'
require 'fhir_client'

class TestReportBuilder
  def self.build(script)
    builder = new
    builder.outline_script(script)
    builder.add_boilerplate(script)
  end

  def report
    @report ||= FHIR::TestReport.new
  end

  def outline_script(script)
    report.setup = outline_setup(script.setup) if script.setup
    report.test = outline_test(script.test) unless script.test.empty?
    report.teardown = outline_teardown(script.teardown) if script.teardown
    report
  end

  def outline_setup(setup)
    action = setup.action.map do |action|
      operation, assert = build_base_action(action)
      FHIR::TestReport::Setup::Action.new(operation: operation, assert: assert)
    end

    FHIR::TestReport::Setup.new(action: action)
  end

  def outline_test(tests)
    tests.map do |test|
      actions = test.action.map do |action|
        operation, assert = build_base_action(action)
        FHIR::TestReport::Test::Action.new(id: action.id, operation: operation, assert: assert)
      end

      FHIR::TestReport::Test.new(action: actions)
    end
  end

  def outline_teardown(teardown)
    action = teardown.action.map do |action|
      operation, assert = build_base_action(action)
      FHIR::TestReport::Teardown::Action.new(operation: operation)
    end

    FHIR::TestReport::Teardown.new(action: action)
  end

  def build_base_action(action)
    operation = outline_operation(action.operation) if action.operation
    assert = outline_assert(action.assert) if (action.respond_to?(:assert) and action.assert)

    return operation, assert
  end

  def outline_operation(operation)
    FHIR::TestReport::Setup::Action::Operation.new({
      id: operation.label || operation.id,
      message: operation.description
    })
  end

  def outline_assert(assert)
    FHIR::TestReport::Setup::Action::Assert.new({
      id: assert.label || assert.id,
      message: assert.description
    })
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

  # def finalize_report
  #   # result:
  #   # score:
  #   # issued:
  # end
end