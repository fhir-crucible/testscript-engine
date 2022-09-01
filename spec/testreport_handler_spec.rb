require 'TestReportHandler'

class TestReportHandlerTestClass
  include TestReportHandler

  def script
    @script ||= FHIR.from_contents(File.read('spec/fixtures/basic_testscript.json'))
  end
end

describe TestReportHandler do
  describe 'TestReportHandler Module' do
    before(:each) { @handler = TestReportHandlerTestClass.new }

    describe '.testreport' do
      it 'gets report from report_builder' do
        expect(@handler.testreport).to eq(@handler.report_builder.report)
      end
    end

    describe '.fresh_testreport' do
      it 'creates and sets a new report' do
        old_report = @handler.testreport
        @handler.fresh_testreport
        new_report = @handler.testreport

        expect(new_report).to eq(old_report)
        expect(new_report.object_id).not_to eq(old_report.object_id)
      end
    end

    describe '.report_builder' do
      it 'returns the builder' do
        expect(@handler.report_builder.class)
          .to eq(TestReportHandler::TestReportBuilder)

        expect(@handler.report_builder.object_id)
          .to eq(@handler.instance_variable_get(:@report_builder).object_id)
      end

      it 'generates a new builder, if no builder' do
        expect(@handler).to receive(:fresh_builder)

        @handler.instance_variable_set(:@report_builder, nil)
        @handler.report_builder
      end
    end

    describe '.fresh_builder' do
      it 'creates clone of builder template' do
        clone = @handler.fresh_builder

        expect(clone.report).to eq(@handler.testreport)
        expect(clone.object_id).not_to eq(@handler.report_builder.object_id)
      end
    end

    describe '.builder_template' do
      it 'returns the builder template' do
        expect(@handler.builder_template.class)
          .to eq(TestReportHandler::TestReportBuilder)

        expect(@handler.builder_template.object_id)
          .to eq(@handler.instance_variable_get(:@builder_template).object_id)
      end

      it 'creates builder template, if no template' do
        @handler.instance_variable_set(:@builder_template, nil)

        expect(@handler.builder_template).to be
      end
    end
  end

  describe TestReportHandler::TestReportBuilder do
    before(:each) do
      @script = FHIR.from_contents(File.read('spec/fixtures/basic_testscript.json'))
      @report_outline = FHIR.from_contents(File.read('spec/fixtures/testreport_outline.json'))
      @script_setup = @script.setup
      @report_outline_setup = @report_outline.setup
      @script_test = @script.test
      @report_outline_test = @report_outline.test
      @script_teardown = @script.teardown
      @report_outline_teardown = @report_outline.teardown
      @builder = described_class.new(@script)
    end

    describe '.initialize' do
      context 'with just script.setup defined' do
        before do
          @script.test = []
          @script.teardown = nil
          @report_outline.test = []
          @report_outline.teardown = nil
        end

        it 'returns builder with report.setup' do
          builder = TestReportHandler::TestReportBuilder.new(@script)

          expect(builder.report).to eq(@report_outline)
        end
      end

      context 'with script.test' do
        before do
          @script.setup = nil
          @script.teardown = nil
          @report_outline.setup = nil
          @report_outline.teardown = nil
        end

        it 'returns builder with report.test' do
          builder = TestReportHandler::TestReportBuilder.new(@script)

          expect(builder.report).to eq(@report_outline)
        end
      end

      context 'with script.teardown' do
        before do
          @script.setup = nil
          @script.test = []
          @report_outline.setup = nil
          @report_outline.test = []
        end

        it 'returns builder with report.teardown' do
          builder = TestReportHandler::TestReportBuilder.new(@script)

          expect(builder.report).to eq(@report_outline)
        end
      end

      context 'with all script phases' do
        it 'returns builder with all report phases' do
          builder = TestReportHandler::TestReportBuilder.new(@script)

          expect(builder.report).to eq(@report_outline)
        end
      end
    end

    describe '.build_setup' do
      context 'with single operation action' do
        before do
          @script_setup.action = @script_setup.action.slice(0,1)
          @report_outline_setup.action = @report_outline_setup.action.slice(0,1)
        end

        it 'returns setup outline with operation' do
          result = @builder.build_setup(@script_setup)

          expect(result).to eq(@report_outline_setup)
          expect(result.action.first.operation).to be
        end
      end

      context 'with single assert action' do
        before do
          @script_setup.action = @script_setup.action.slice(1,2)
          @report_outline_setup.action = @report_outline_setup.action.slice(1,2)
        end

        it 'returns setup outline with assert' do
          result = @builder.build_setup(@script_setup)

          expect(result).to eq(@report_outline_setup)
          expect(result.action.first.assert).to be
        end
      end

      context 'with operation and assert actions' do
        it 'returns setup outline with both' do
          result = @builder.build_setup(@script_setup)

          expect(result).to eq(@report_outline_setup)
          expect(result.action.first.operation).to be
          expect(result.action.second.assert).to be
        end
      end
    end

    describe '.build_test' do
      context 'with single test' do
        before do
          @script_test = @script_test.slice(0,1)
          @report_outline_test = @report_outline_test.slice(0,1)
        end

        context 'and action' do
          before do
            @script_test.first.action = @script_test.first.action.slice(0,1)
            @report_outline_test.first.action = @report_outline_test.first.action.slice(0,1)
          end

          it 'returns singleton array containing action' do
            result = @builder.build_test(@script_test)

            expect(result).to eq(@report_outline_test)
          end
        end

        context 'and mix of operations and asserts' do
          it 'returns singleton array containing mix' do
            result = @builder.build_test(@script_test)

            expect(result).to eq(@report_outline_test)
            expect(result.first.action.first.operation).to be
            expect(result.first.action.second.assert).to be
          end
        end
      end

      context 'with tests' do
        context 'and action' do
          before do
            @script_test.each { |test| test.action = test.action.slice(0,1) }
            @report_outline_test.each { |test| test.action = test.action.slice(0,1) }
          end

          it 'returns array of tests containing action' do
            result = @builder.build_test(@script_test)

            expect(result).to eq(@report_outline_test)
          end
        end

        context 'and mix of operations and asserts' do
          it 'returns array of tests containing mix' do
            result = @builder.build_test(@script_test)

            expect(result).to eq(@report_outline_test)
            expect(result.first.action.first.operation).to be
            expect(result.first.action.second.assert).to be
            expect(result.second.action.first.operation).to be
            expect(result.second.action.second.assert).to be
          end
        end
      end
    end

    describe '.build_teardown' do
      context 'with single operation' do
        before do
          @script_teardown.action = @script_teardown.action.slice(0,1)
          @report_outline_teardown.action = @report_outline_teardown.action.slice(0,1)
        end

        it 'returns teardown outline with operation' do
          result = @builder.build_teardown(@script_teardown)

          expect(result).to eq(@report_outline_teardown)
          expect(result.action.first.operation).to be
        end
      end

      context 'with multiple operations' do
        it 'returns teardown outline with operations' do
          result = @builder.build_teardown(@script_teardown)

          expect(result).to eq(@report_outline_teardown)
          expect(result.action.first.operation).to be
          expect(result.action.second.operation).to be
        end
      end
    end

    describe  '.build_action' do
      context 'given Setup' do
        it 'returns Setup action outline with operation' do
          result = @builder.build_action(@script_setup.action.first)

          expect(result).to eq(@report_outline_setup.action.first)
          expect(result.operation).to be
        end

        it 'returns Setup outline with assert' do
          result = @builder.build_action(@script_setup.action.second)

          expect(result).to eq(@report_outline_setup.action.second)
          expect(result.assert).to be
        end
      end

      context 'given Test' do
        it 'returns Test outline with operation' do
          result = @builder.build_action(@script_test.first.action.first)

          expect(result).to eq(@report_outline_test.first.action.first)
          expect(result.operation).to be
        end

        it 'returns Test outline with assert' do
          result = @builder.build_action(@script_test.first.action.second)

          expect(result).to eq(@report_outline_test.first.action.second)
          expect(result.assert).to be
        end
      end

      context 'given Teardown action' do
        it 'returns a Teardown action outline with operation' do
          result = @builder.build_action(@script_teardown.action.first)

          expect(result).to eq(@report_outline_teardown.action.first)
          expect(result.operation).to be
        end
      end
    end

    describe '.build_operation' do
      it 'creates testreport operation' do
        result = @builder.build_operation(@script_setup.action.first.operation)

        expect(result).to eq(@report_outline_setup.action.first.operation)
      end
    end

    describe '.build_assert' do
      it 'creates testreport assert' do
        result = @builder.build_assert(@script_setup.action.first.assert)

        expect(result).to eq(@report_outline_setup.action.first.assert)
      end
    end

    describe '.store_action' do
      before { @builder.actions.clear }

      it 'updates the actions array' do
        @builder.store_action(@report_outline_setup.action.first.operation)

        expect(@builder.actions).to eq([@report_outline_setup.action.first.operation])
      end
    end

    describe '.next_action' do
      it 'finalizes report if no more actions' do
        expect(@builder).to receive(:finalize_report)

        (@builder.next_action) while @builder.actions.length > 0
      end
    end

    describe '.add_boilerplate' do
      it 'updates the report' do
        @builder.add_boilerplate(@script)

        expect(@builder.report.name).to be
        expect(@builder.report.id).to be
        expect(@builder.report.tester).to be
        expect(@builder.report.testScript).to be
        expect(@builder.report.status).to be
        expect(@builder.report.result).to be
      end
    end

    describe '.finalize_report' do
      it 'updates the report' do
        @builder.finalize_report

        expect(@builder.report.status).to be
        expect(@builder.report.result).to be
        expect(@builder.report.score).to be
        expect(@builder.report.issued).to be
      end
    end

    describe '.pass' do
      let(:builder) { TestReportHandler::TestReportBuilder.new(@script) }

      it 'updates the report and removes the action from the internal queue' do
        pass_action = builder.action
        builder.pass

        expect(builder.actions).not_to eq(pass_action)
        expect(builder.actions.length).to eq(13)
        expect(builder.report.setup.action.first.operation.result).to eq('pass')
      end
    end

    describe '.skip' do
      let(:builder) { TestReportHandler::TestReportBuilder.new(@script) }

      it 'updates the report and removes the action from the internal queue' do
        skip_action = builder.action
        builder.skip('test_message')

        expect(builder.actions).not_to eq(skip_action)
        expect(builder.actions.length).to eq(13)
        expect(builder.report.setup.action.first.operation.result).to eq('skip')
        expect(builder.report.setup.action.first.operation.message).to eq('test_message')
      end
    end

    describe '.warning' do
      let(:builder) { TestReportHandler::TestReportBuilder.new(@script) }

      it 'updates the report and removes the action from the internal queue' do
        warn_action = builder.action
        builder.warning('test_message')

        expect(builder.actions).not_to eq(warn_action)
        expect(builder.actions.length).to eq(13)
        expect(builder.report.setup.action.first.operation.result).to eq('warning')
        expect(builder.report.setup.action.first.operation.message).to eq('test_message')
      end
    end

    describe '.fail' do
      let(:builder) { TestReportHandler::TestReportBuilder.new(@script) }

      it 'updates the report and removes the action from the internal queue' do
        fail_action = @builder.action
        builder.fail('test_message')

        expect(builder.actions).not_to eq(fail_action)
        expect(builder.actions.length).to eq(13)
        expect(builder.report.setup.action.first.operation.result).to eq('fail')
        expect(builder.report.setup.action.first.operation.message).to eq('test_message')
      end
    end

    describe '.error' do
      let(:builder) { TestReportHandler::TestReportBuilder.new(@script) }

      it 'updates the report and removes the action from the internal queue' do
        error_action = @builder.action
        builder.error('test_message')

        expect(builder.actions).not_to eq(error_action)
        expect(builder.actions.length).to eq(13)
        expect(builder.report.setup.action.first.operation.result).to eq('error')
        expect(builder.report.setup.action.first.operation.message).to eq('test_message')
      end
    end

    describe '.clone' do
      context 'on empty builder' do
        it 'creates an empty deep clone' do
          clone = @builder.clone

          expect(clone.pass_count).to eq(@builder.pass_count)
          expect(clone.total_test_count).to eq(@builder.total_test_count)
          expect(clone.actions).to eq(@builder.actions)
          expect(clone.report).to eq(@builder.report)
        end
      end

      context 'of initialized builder' do
        it 'creates a deep clone with distinct objects' do
          builder = TestReportHandler::TestReportBuilder.new(@script)
          clone = builder.clone

          expect(clone.pass_count).to eq(builder.pass_count)
          expect(clone.total_test_count).to eq(builder.total_test_count)
          expect(clone.actions).to eq(builder.actions)
          expect(clone.report).to eq(builder.report)

          for i in 0..builder.total_test_count do
            clone.actions[i] != builder.actions[i]
          end

          expect(clone.report.object_id).not_to eq(builder.report.object_id)
          expect(clone.report.setup.object_id).not_to eq(builder.report.setup.object_id)
          expect(clone.report.test.object_id).not_to eq(builder.report.test.object_id)
          expect(clone.report.teardown.object_id).not_to eq(builder.report.teardown.object_id)
        end
      end
    end
  end
end