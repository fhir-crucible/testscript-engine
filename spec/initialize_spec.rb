# frozen_string_literal: true
require_relative '../lib/testscript_engine/testscript_runnable'
require_relative '../lib/testscript_engine/output/message_handler'

include MessageHandler

describe TestScriptRunnable do
  before(:all) do
    @invalid_script = FHIR::TestScript.new
    @script = FHIR.from_contents(File.read('spec/examples/basic_testscript.json'))
  end

  describe '.initialize' do
    it 'given non-TestScript input raises an error' do
      expect { TestScriptRunnable.new(nil, lambda { |k| {}[k] }) }
        .to raise_error(ArgumentError, messages(:bad_script))
    end

    it 'given invalid TestScript input raises an error' do
      expect { TestScriptRunnable.new(@invalid_script, lambda { |k| {}[k] }) }
        .to raise_error(ArgumentError, messages(:invalid_script_input))
    end

    context 'given valid TestScript' do
      it 'stores script' do
        result = TestScriptRunnable.new(@script, lambda { |k| {}[k] })

        expect(result.script).to be(@script)
      end

      # it 'calls load fixtures' do
      #   expect_any_instance_of(described_class).to receive(:load_fixtures)

      #   TestScriptRunnable.new(@script)
      # end
    end
  end
end