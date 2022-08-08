require 'TestReportHandler'

describe TestReportBuilder do
  before(:all) do
    @id = 'some_id'
    @builder = described_class.new
    @description = 'some_description'
    @report_input = { id: @id, message: @description }
    @script_input = { id: @id, description: @description }
    @op = FHIR::TestScript::Setup::Action::Operation.new(@script_input)
    @assert = FHIR::TestScript::Setup::Action::Assert.new(@script_input)

    @report_op = FHIR::TestReport::Setup::Action::Operation.new(@report_input)
    @report_assert = FHIR::TestReport::Setup::Action::Assert.new(@report_input)
  end

  describe '.outline_operation' do
    it 'returns an Operation report element' do
      result = @builder.outline_operation(FHIR::TestScript::Setup::Action::Operation.new)

      expect(result).to eq(FHIR::TestReport::Setup::Action::Operation.new)
    end

    it 'given non-empty script returns an Operation report element with ID and message' do
      result = @builder.outline_operation(@op)

      expect(result).to eq(@report_op)
    end
  end

  describe '.outline_assert' do
    it 'returns an Assert report element' do
      result = @builder.outline_assert(FHIR::TestScript::Setup::Action::Assert.new)

      expect(result).to eq(FHIR::TestReport::Setup::Action::Assert.new)
    end

    it 'given non-empty script returns an Assert report element with ID and message' do
      result = @builder.outline_assert(@assert)

      expect(result).to eq(@report_assert)
    end
  end

  describe '.build_base_action' do
    context 'given Setup::Action ' do
      let(:action) { FHIR::TestScript::Setup::Action.new }

      it 'with operation, returns operation and nil assert' do
        action.operation = @op

        result = @builder.build_base_action(action)

        expect(result[0]).to eq(@report_op)
        expect(result[1]).to be_nil
      end

      it 'with assert, returns assert and nil operation' do
        action.assert = @assert

        result = @builder.build_base_action(action)

        expect(result[0]).to be_nil
        expect(result[1]).to eq(@report_assert)
      end
    end

    context 'given Setup::Test ' do
      let(:action) { FHIR::TestScript::Test::Action.new }

      it 'with operation, returns operation and nil assert' do
        action.operation = @op

        result = @builder.build_base_action(action)

        expect(result[0]).to eq(@report_op)
        expect(result[1]).to be_nil
      end

      it 'with assert, returns assert and nil operation' do
        action.assert = @assert

        result = @builder.build_base_action(action)

        expect(result[0]).to be_nil
        expect(result[1]).to eq(@report_assert)
      end
    end

    context 'given Teardown::Action ' do
      let(:action) { FHIR::TestScript::Teardown::Action.new }

      it 'with operation, returns operation and nil assert' do
        action.operation = @op

        result = @builder.build_base_action(action)

        expect(result[0]).to eq(@report_op)
        expect(result[1]).to be_nil
      end
    end
  end

  describe '.outline_setup' do
    let(:setup) { FHIR::TestScript::Setup.new }
    let(:report_setup) { FHIR::TestReport::Setup.new }
    let(:action_op) { FHIR::TestScript::Setup::Action.new(operation: @op) }
    let(:action_assert) { FHIR::TestScript::Setup::Action.new(assert: @assert) }
    let(:report_action_op) { FHIR::TestReport::Setup::Action.new(operation: @report_op) }
    let(:report_action_assert) { FHIR::TestReport::Setup::Action.new(assert: @report_assert) }

    it 'given setup w/out action, returns setup report w/out action' do
      result = @builder.outline_setup(setup)

      expect(result).to eq(report_setup)
    end

    context 'given setup w/ action operation' do
      before do
        setup.action = [action_op]
        report_setup.action = [report_action_op]
      end

      it 'returns setup report elem w/ action operation' do
        result = @builder.outline_setup(setup)

        expect(result).to eq(report_setup)
      end
    end

    context 'given setup w/ action assert' do
      before do
        setup.action = [action_assert]
        report_setup.action = [report_action_assert]
      end

      it 'returns setup report elem w/ action assert' do
        result = @builder.outline_setup(setup)

        expect(result).to eq(report_setup)
      end
    end

    context 'given setup w/ mix of action types' do
      let(:action_mix) {
        [action_op, action_assert, action_assert, action_assert, action_op]
      }
      let(:report_action_mix) {
        [report_action_op,
        report_action_assert,
        report_action_assert,
        report_action_assert,
        report_action_op]
      }
      before do
        setup.action = action_mix
        report_setup.action = report_action_mix
      end

      it 'returns setup w/ matching, ordered mix of action types' do
        result = @builder.outline_setup(setup)

        expect(result).to eq(report_setup)
      end
    end
  end

  describe 'outline_test' do
    let(:test) { FHIR::TestScript::Test.new }
    let(:report_test) { FHIR::TestReport::Test.new }
    let(:action_op) { FHIR::TestScript::Test::Action.new(operation: @op) }
    let(:action_assert) { FHIR::TestScript::Test::Action.new(assert: @assert) }
    let(:report_action_op) { FHIR::TestReport::Test::Action.new(operation: @report_op) }
    let(:report_action_assert) { FHIR::TestReport::Test::Action.new(assert: @report_assert) }
    let(:action_mix) {
      [action_op, action_op, action_assert, action_assert]
    }
    let(:report_action_mix) {
      [report_action_op,
      report_action_op,
      report_action_assert,
      report_action_assert]
    }

    context 'given singleton test' do
      it 'w/out action, returns singleton test report elem w/out action' do
        result = @builder.outline_test([test])

        expect(result).to eq([report_test])
      end

      context 'w/ operation action' do
        before do
          test.action = [action_op]
          report_test.action = [report_action_op]
        end

        it 'returns singletone test report elem w/ operation action' do
          result = @builder.outline_test([test])

          expect(result).to eq([report_test])
        end
      end

      context 'w/ assert action' do
        before do
          test.action = [action_assert]
          report_test.action = [report_action_assert]
        end

        it 'returns singleton test report elem w/ assert action' do
          result = @builder.outline_test([test])

          expect(result).to eq([report_test])
        end
      end

      context 'w/ mix of action types' do
        before do
          test.action = action_mix
          report_test.action = report_action_mix
        end

        it 'returns singleton test report elem w/ ordered mix of action types' do
          result = @builder.outline_test([test])

          expect(result).to eq([report_test])
        end
      end
    end

    context 'given test array' do
      it 'w/out action, returns array of test report elems w/out action' do
        result = @builder.outline_test([test, test, test])

        expect(result).to eq([report_test, report_test, report_test])
      end

      context 'w/ operation action' do
        before do
          test.action = [action_op]
          report_test.action = [report_action_op]
        end

        it 'returns singular test report elem w/ operation action' do
          result = @builder.outline_test([test, test, test])

          expect(result).to eq([report_test, report_test, report_test])
        end
      end

      context 'w/ assert action' do
        before do
          test.action = [action_assert]
          report_test.action = [report_action_assert]
        end

        it 'returns singular test report elem w/ assert action' do
          result = @builder.outline_test([test, test, test])

          expect(result).to eq([report_test, report_test, report_test])
        end
      end

      context 'w/ mix of action types' do
        before do
          test.action = action_mix
          report_test.action = report_action_mix
        end

        it 'returns singular test report elem w/ ordered mix of action types' do
          result = @builder.outline_test([test, test, test])

          expect(result).to eq([report_test, report_test, report_test])
        end
      end
    end
  end

  describe 'outline_teardown' do
    let(:teardown) { FHIR::TestScript::Teardown.new }
    let(:report_teardown) { FHIR::TestReport::Teardown.new }
    let(:action_op) { FHIR::TestScript::Teardown::Action.new(operation: @op) }
    let(:report_action_op) { FHIR::TestReport::Teardown::Action.new(operation: @report_op) }

    it 'given teardown w/out action, returns teardown report w/out action' do
      result = @builder.outline_teardown(teardown)

      expect(result).to eq(report_teardown)
    end

    context 'given teardown w/ action operation' do
      before do
        teardown.action = [action_op]
        report_teardown.action = [report_action_op]
      end

      it 'returns teardown report elem w/ action operation' do
        result = @builder.outline_teardown(teardown)

        expect(result).to eq(report_teardown)
      end
    end

    context 'given teardown w/ multiple action operations' do
      let(:action_mix) {
        [action_op, action_op, action_op]
      }
      let(:report_action_mix) {
        [report_action_op,
        report_action_op,
        report_action_op]
      }
      before do
        teardown.action = action_mix
        report_teardown.action = report_action_mix
      end

      it 'returns teardown w/ multiple action operations' do
        result = @builder.outline_teardown(teardown)

        expect(result).to eq(report_teardown)
      end
    end
  end

  describe 'outline_script' do
    let(:setup_action_op) { FHIR::TestScript::Setup::Action.new(operation: @op) }
    let(:setup_action_assert) { FHIR::TestScript::Setup::Action.new(assert: @assert) }
    let(:report_setup_action_op) { FHIR::TestReport::Setup::Action.new(operation: @report_op) }
    let(:report_setup_action_assert) { FHIR::TestReport::Setup::Action.new(assert: @report_assert) }
    let(:setup) { FHIR::TestScript::Setup.new(action: [
      setup_action_op,
      setup_action_assert,
      setup_action_assert,
      setup_action_op,
      setup_action_assert,
      setup_action_assert,
      setup_action_assert
    ]) }
    let(:report_setup) { FHIR::TestReport::Setup.new(action: [
      report_setup_action_op,
      report_setup_action_assert,
      report_setup_action_assert,
      report_setup_action_op,
      report_setup_action_assert,
      report_setup_action_assert,
      report_setup_action_assert
    ]) }

    let(:test_action_op) { FHIR::TestScript::Test::Action.new(operation: @op) }
    let(:test_action_assert) { FHIR::TestScript::Test::Action.new(assert: @assert) }
    let(:report_test_action_op) { FHIR::TestReport::Test::Action.new(operation: @report_op) }
    let(:report_test_action_assert) { FHIR::TestReport::Test::Action.new(assert: @report_assert) }
    let(:test) { FHIR::TestScript::Test.new(action: [
      test_action_op,
      test_action_assert,
      test_action_assert
    ]) }
    let(:report_test) { FHIR::TestReport::Test.new(action: [
      report_test_action_op,
      report_test_action_assert,
      report_test_action_assert
    ])
    }

    let(:teardown_action_op) { FHIR::TestScript::Teardown::Action.new(operation: @op) }
    let(:report_teardown_action_op) { FHIR::TestReport::Teardown::Action.new(operation: @report_op) }
    let(:teardown) { FHIR::TestScript::Teardown.new(action: [
      teardown_action_op,
      teardown_action_op,
      teardown_action_op
    ]) }
    let(:report_teardown) { FHIR::TestReport::Teardown.new(action: [
      report_teardown_action_op,
      report_teardown_action_op,
      report_teardown_action_op
    ]) }

    let(:script) {
      FHIR::TestScript.new(setup: setup, test: [test, test, test], teardown: teardown)
    }
    let(:report) {
      FHIR::TestReport.new(setup: report_setup, test: [report_test, report_test, report_test], teardown: report_teardown)
    }

    it 'given TestScript, outlines its Setup, Test, and Teardown sections' do
      result = @builder.outline_script(script)

      expect(result).to eq(report)
    end
  end
end