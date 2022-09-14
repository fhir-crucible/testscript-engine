# frozen_string_literal: true
require_relative '../lib/testscript_runnable'
require_relative '../lib/message_handler'

include MessageHandler

describe TestScriptRunnable do
  before(:all) do
    @invalid_script = FHIR::TestScript.new
    @script = FHIR.from_contents(File.read('spec/fixtures/basic_testscript.json'))
  end

  describe '.initialize' do
    it 'given non-TestScript input raises an error' do
      expect { TestScriptRunnable.new(nil) }
        .to raise_error(ArgumentError, messages(:bad_script))
    end

    it 'given invalid TestScript input raises an error' do
      expect { TestScriptRunnable.new(@invalid_script) }
        .to raise_error(ArgumentError, messages(:invalid_script))
    end

    context 'given valid TestScript' do
      it 'stores script' do
        result = TestScriptRunnable.new(@script)

        expect(result.script).to be(@script)
      end

      it 'calls load fixtures' do
        expect_any_instance_of(described_class).to receive(:load_fixtures)

        TestScriptRunnable.new(@script)
      end
    end
  end
end