require_relative 'testreport_handler'


class Tester
  include TestReportHandler

  def script
    @script ||= begin
      operation = FHIR::TestScript::Setup::Action::Operation.new(id: 'sample_operation')
      assert = FHIR::TestScript::Setup::Action::Assert.new(id: 'sample_assert')
      FHIR::TestScript.new({
        setup: FHIR::TestScript::Setup.new(action: [
          FHIR::TestScript::Setup::Action.new(operation: operation),
          FHIR::TestScript::Setup::Action.new(assert: assert),
          FHIR::TestScript::Setup::Action.new(assert: assert)
        ]),
        test: [FHIR::TestScript::Test.new(action: [
                FHIR::TestScript::Test::Action.new(operation: operation),
                FHIR::TestScript::Test::Action.new(assert: assert)
              ]),
              FHIR::TestScript::Test.new(action: [
                FHIR::TestScript::Setup::Action.new(operation: operation),
                FHIR::TestScript::Test::Action.new(assert: assert)
              ])],
        teardown: FHIR::TestScript::Teardown.new(action: [
          FHIR::TestScript::Teardown::Action.new(operation: operation)
        ])
      })
    end
  end

  # I don't understand why this doesn't have access to script
  def initialize
    binding.pry
    pass
  end
end

binding.pry
tester = Tester.new
binding.pry
