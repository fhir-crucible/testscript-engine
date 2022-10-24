# frozen_string_literal: true
require_relative '../lib/testscript_engine/testscript_runnable'
require_relative '../lib/testscript_engine/output/message_handler'

describe TestScriptRunnable do
  before(:all) do
    @script = FHIR.from_contents(File.read('spec/examples/basic_testscript.json'))
    @patient = FHIR.from_contents(File.read('spec/examples/example_patient.json'))
    @runnable = described_class.new(@script.deep_dup)
  end

  describe '.handle_actions' do
    # TODO
  end
end