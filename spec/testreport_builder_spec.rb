require 'TestReportHandler'

class TestReportBuilderTestClass < TestReportHandler::TestReportBuilder
  class << self
    attr_accessor :script

    def script
      @script ||= FHIR::TestScript.new
    end
  end

  def script
    self.class.script
  end
end

describe TestReportHandler do

  describe 'TestReportHandler Module' do

  end

  describe TestReportHandler::TestReportBuilder do
    before(:all) do
      id = 'test_id'
      description = 'test_description'
      @builder = TestReportBuilderTestClass.new
      @script_operation = FHIR::TestScript::Setup::Action::Operation.new({
        id: id,
        description: description
      })
      @report_operation = FHIR::TestReport::Setup::Action::Operation.new({
        id: id,
        message: description
      })
      @script_assert = FHIR::TestScript::Setup::Action::Assert.new({
        id: id,
        description: description
      })
      @report_assert = FHIR::TestReport::Setup::Action::Assert.new({
        id: id,
        message: description
      })
      @script_setup_action_op = FHIR::TestScript::Setup::Action.new({
        operation: @script_operation
      })
      @report_setup_action_op = FHIR::TestReport::Setup::Action.new({
        operation: @report_operation
      })
      @script_setup_action_assert = FHIR::TestScript::Setup::Action.new({
        assert: @script_assert
      })
      @report_setup_action_assert = FHIR::TestReport::Setup::Action.new({
        assert: @report_assert
      })
      @script_test_action_op = FHIR::TestScript::Test::Action.new({
        operation: @script_operation
      })
      @report_test_action_op = FHIR::TestReport::Test::Action.new({
        operation: @report_operation
      })
      @script_test_action_assert = FHIR::TestScript::Test::Action.new({
        assert: @script_assert
      })
      @report_test_action_assert = FHIR::TestReport::Test::Action.new({
        assert: @report_assert
      })
      @script_teardown_action_op = FHIR::TestScript::Teardown::Action.new({
        operation: @script_operation
      })
      @report_teardown_action_op = FHIR::TestReport::Teardown::Action.new({
        operation: @report_operation
      })
      @script_setup = FHIR::TestScript::Setup.new({
        action: [@script_setup_action_op, @script_setup_action_assert, @script_setup_action_assert]
      })
      @report_setup = FHIR::TestReport::Setup.new({
        action: [@report_setup_action_op, @report_setup_action_assert, @report_setup_action_assert]
      })
      @script_test = FHIR::TestScript::Test.new({
        action: [@script_test_action_op, @script_test_action_assert, @script_test_action_assert]
      })
      @report_test = FHIR::TestReport::Test.new({
        action: [@report_test_action_op, @report_test_action_assert, @report_test_action_assert]
      })
      @script_teardown = FHIR::TestScript::Teardown.new({
        action: [@script_teardown_action_op, @script_teardown_action_op]
      })
      @report_teardown = FHIR::TestReport::Teardown.new({
        action: [@report_teardown_action_op, @report_teardown_action_op]
      })
      @script = FHIR::TestScript.new({
        name: 'test-name',
        id: 'test-id',
        url: 'test-url',
        setup: @script_setup,
        test: [@script_test, @script_test, @script_test],
        teardown: @script_teardown
      })
      @report = FHIR::TestReport.new({
        setup: @report_setup,
        test: [@report_test, @report_test, @report_test],
        teardown: @report_teardown
      })
    end

    describe '.initialize' do
      context 'with script.setup' do
        before do
          TestReportBuilderTestClass.script = FHIR::TestScript.new({ setup: @script_setup })
          @report = FHIR::TestReport.new({ setup: @report_setup })
        end

        it 'returns builder with report.setup' do
          builder = TestReportBuilderTestClass.new

          expect(builder.report).to eq(@report)
        end
      end

      context 'with script.test' do
        before do
          TestReportBuilderTestClass.script = FHIR::TestScript.new({ test: [@script_test, @script_test, @script_test] })
          @report = FHIR::TestReport.new({ test: [@report_test, @report_test, @report_test] })
        end

        it 'returns builder with report.test' do
          builder = TestReportBuilderTestClass.new

          expect(builder.report).to eq(@report)
        end
      end

      context 'with script.teardown' do
        before do
          TestReportBuilderTestClass.script = FHIR::TestScript.new({ teardown: @script_teardown })
          @report = FHIR::TestReport.new({ teardown: @report_teardown })
        end

        it 'returns builder with report.teardown' do
          builder = TestReportBuilderTestClass.new

          expect(builder.report).to eq(@report)
        end
      end

      context 'with all script phases' do
        before { TestReportBuilderTestClass.script = @script }

        it 'returns builder with all report phases' do
          builder = TestReportBuilderTestClass.new

          expect(builder.report).to eq(@report)
        end
      end
    end

    describe '.outline_setup' do
      context 'with single operation action' do
        let(:script_setup) { FHIR::TestScript::Setup.new(action: @script_test_action_op) }
        let(:report_setup) { FHIR::TestReport::Setup.new(action: @report_test_action_op) }

        it 'returns setup outline with operation' do
          result = @builder.outline_setup(script_setup)

          expect(result).to eq(report_setup)
        end
      end

      context 'with several operation actions' do
        let(:script_setup) { FHIR::TestScript::Setup.new({ action: [@script_setup_action_op, @script_setup_action_op, @script_setup_action_op] }) }
        let(:report_setup) { FHIR::TestReport::Setup.new({ action: [@report_setup_action_op, @report_setup_action_op, @report_setup_action_op] }) }

        it 'returns setup outline including operations' do
          result = @builder.outline_setup(script_setup)

          expect(result).to eq(report_setup)
        end
      end

      context 'with single assert action' do
        let(:script_setup) { FHIR::TestScript::Setup.new(action: @script_test_action_assert) }
        let(:report_setup) { FHIR::TestReport::Setup.new(action: @report_test_action_assert) }

        it 'returns setup outline with assert' do
          result = @builder.outline_setup(script_setup)

          expect(result).to eq(report_setup)
        end
      end

      context 'with several assert actions' do
        let(:script_setup) { FHIR::TestScript::Setup.new({ action: [@script_setup_action_assert, @script_setup_action_assert, @script_setup_action_assert] }) }
        let(:report_setup) { FHIR::TestReport::Setup.new({ action: [@report_setup_action_assert, @report_setup_action_assert, @report_setup_action_assert] }) }

        it 'returns setup outline with asserts' do
          result = @builder.outline_setup(script_setup)

          expect(result).to eq(report_setup)
        end
      end

      context 'with operation and assert actions' do
        it 'returns setup outline with both' do
          result = @builder.outline_setup(@script_setup)

          expect(result).to eq(@report_setup)
        end
      end
    end

    describe '.outline_test' do
      context 'with single test' do
        context 'and single action' do
          let(:script_test) { FHIR::TestScript::Test.new({ action: @script_test_action_op }) }
          let(:report_test) { FHIR::TestReport::Test.new({ action: @report_test_action_op }) }

          it 'returns singleton array containing test outline with action' do
            result = @builder.outline_test([script_test])

            expect(result).to eq([report_test])
          end
        end

        context 'and multiple operations' do
          let(:script_test) { FHIR::TestScript::Test.new({ action: [@script_test_action_op, @script_test_action_op, @script_test_action_op] }) }
          let(:report_test) { FHIR::TestReport::Test.new({ action: [@report_test_action_op, @report_test_action_op, @report_test_action_op] }) }

          it 'returns singleton array containing test outline with operations' do
            result = @builder.outline_test([script_test])

            expect(result).to eq([report_test])
          end
        end

        context 'and multiple asserts' do
          let(:script_test) { FHIR::TestScript::Test.new({ action: [@script_test_action_assert, @script_test_action_assert, @script_test_action_assert] }) }
          let(:report_test) { FHIR::TestReport::Test.new({ action: [@report_test_action_assert, @report_test_action_assert, @report_test_action_assert] }) }

          it 'returns singleton array containing test outline with asserts' do
            result = @builder.outline_test([script_test])

            expect(result).to eq([report_test])
          end
        end

        context 'and mix of operations and asserts' do
          it 'returns singleton array containing test outline with mix' do
            result = @builder.outline_test([@script_test])

            expect(result).to eq([@report_test])
          end
        end
      end

      context 'with tests' do
        context 'and single action' do
          let(:script_test) { FHIR::TestScript::Test.new({ action: @script_test_action_op }) }
          let(:report_test) { FHIR::TestReport::Test.new({ action: @report_test_action_op }) }

          it 'returns singleton array containing test outline with action' do
            result = @builder.outline_test([script_test, script_test, script_test])

            expect(result).to eq([report_test, report_test, report_test])
          end
        end

        context 'and multiple operations' do
          let(:script_test) { FHIR::TestScript::Test.new({ action: [@script_test_action_op, @script_test_action_op, @script_test_action_op] }) }
          let(:report_test) { FHIR::TestReport::Test.new({ action: [@report_test_action_op, @report_test_action_op, @report_test_action_op] }) }

          it 'returns singleton array containing test outline with operations' do
            result = @builder.outline_test([script_test, script_test, script_test])

            expect(result).to eq([report_test, report_test, report_test])
          end
        end

        context 'and multiple asserts' do
          let(:script_test) { FHIR::TestScript::Test.new({ action: [@script_test_action_assert, @script_test_action_assert, @script_test_action_assert] }) }
          let(:report_test) { FHIR::TestReport::Test.new({ action: [@report_test_action_assert, @report_test_action_assert, @report_test_action_assert] }) }

          it 'returns singleton array containing test outline with asserts' do
            result = @builder.outline_test([script_test, script_test, script_test])

            expect(result).to eq([report_test, report_test, report_test])
          end
        end

        context 'and mix of operations and asserts' do
          it 'returns singleton array containing test outline with actions' do
            result = @builder.outline_test(@script.test)

            expect(result).to eq(@report.test)
          end
        end
      end
    end

    describe '.outline_teardown' do
      context 'with single operation action' do
        let(:script_tear) { FHIR::TestScript::Teardown.new({ action: @script_tear_action_op }) }
        let(:report_tear) { FHIR::TestReport::Teardown.new({ action: @report_tear_action_op }) }

        it 'returns teardown outline with operation' do
          result = @builder.outline_teardown(script_tear)

          expect(result).to eq(report_tear)
        end
      end

      context 'with multiple operations' do
        it 'returns teardown outline with operations' do
          result = @builder.outline_teardown(@script_teardown)

          expect(result).to eq(@report_teardown)
        end
      end
    end

    describe  '.outline_action' do
      context 'given Setup action' do
        it 'returns a Setup action outline with operation' do
          result = @builder.outline_action(@script_setup_action_op)

          expect(result).to eq(@report_setup_action_op)
        end

        it 'returns a Setup action outline with assert' do
          result = @builder.outline_action(@script_setup_action_assert)

          expect(result).to eq(@report_setup_action_assert)
        end
      end

      context 'given Test action' do
        it 'returns a Test action outline with operation' do
          result = @builder.outline_action(@script_test_action_op)

          expect(result).to eq(@report_test_action_op)
        end

        it 'returns a Test action outline with assert' do
          result = @builder.outline_action(@script_test_action_assert)

          expect(result).to eq(@report_test_action_assert)
        end
      end

      context 'given Teardown action' do
        it 'returns a Teardown action outline with operation' do
          result = @builder.outline_action(@script_teardown_action_op)

          expect(result).to eq(@report_teardown_action_op)
        end
      end
    end

    describe '.outline_operation' do
      it 'creates an identical testreport operation' do
        result = @builder.outline_operation(@script_operation)

        expect(result).to eq(@report_operation)
      end
    end

    describe '.outline_assert' do
      it 'creates an identical testreport operation' do
        result = @builder.outline_assert(@script_assert)

        expect(result).to eq(@report_assert)
      end
    end

    describe '.store_action' do
      before { @builder.actions.clear }

      it 'updates the actions array' do
        @builder.store_action(@report_operation)

        expect(@builder.actions).to eq([@report_operation])
      end
    end

    describe '.next_action' do
      it 'finalizes report if no more actions' do
        expect(@builder).to receive(:finalize_report)

        @builder.next_action
      end
    end

    describe '.add_boilerplate' do
      before { @builder = TestReportBuilderTestClass.new }

      it 'updates the report' do
        @builder.add_boilerplate

        expect(@builder.report.name).to be
        expect(@builder.report.id).to be
        expect(@builder.report.tester).to be
        expect(@builder.report.testScript).to be
        expect(@builder.report.status).to be
        expect(@builder.report.result).to be
      end
    end

    describe '.finalize_report' do
      before { @builder = TestReportBuilderTestClass.new }

      it 'updates the report' do
        @builder.finalize_report

        expect(@builder.report.status).to be
        expect(@builder.report.result).to be
        expect(@builder.report.score).to be
        expect(@builder.report.issued).to be
      end
    end

    describe '.pass' do
      before { @builder = TestReportBuilderTestClass.new }

      it 'updates the report and removes the action from the internal queue' do
        pass_action = @builder.action
        @builder.pass

        expect(@builder.actions).not_to eq(pass_action)
        expect(@builder.actions.length).to eq(13)
        expect(@builder.report.setup.action.first.operation.result).to eq('pass')
      end
    end

    describe '.skip' do
      before { @builder = TestReportBuilderTestClass.new }

      it 'updates the report and removes the action from the internal queue' do
        skip_action = @builder.action
        @builder.skip('test_message')

        expect(@builder.actions).not_to eq(skip_action)
        expect(@builder.actions.length).to eq(13)
        expect(@builder.report.setup.action.first.operation.result).to eq('skip')
        expect(@builder.report.setup.action.first.operation.message).to eq('test_message')
      end
    end

    describe '.warning' do
      before { @builder = TestReportBuilderTestClass.new }

      it 'updates the report and removes the action from the internal queue' do
        warn_action = @builder.action
        @builder.warning('test_message')

        expect(@builder.actions).not_to eq(warn_action)
        expect(@builder.actions.length).to eq(13)
        expect(@builder.report.setup.action.first.operation.result).to eq('warning')
        expect(@builder.report.setup.action.first.operation.message).to eq('test_message')
      end
    end

    describe '.fail' do
      before { @builder = TestReportBuilderTestClass.new }

      it 'updates the report and removes the action from the internal queue' do
        fail_action = @builder.action
        @builder.fail('test_message')

        expect(@builder.actions).not_to eq(fail_action)
        expect(@builder.actions.length).to eq(13)
        expect(@builder.report.setup.action.first.operation.result).to eq('fail')
        expect(@builder.report.setup.action.first.operation.message).to eq('test_message')
      end
    end
  end
end