# frozen_string_literal: true
require_relative '../lib/testscript_runnable'
require_relative '../lib/message_handler'

describe TestScriptRunnable do
  before(:all) do
    @script = FHIR.from_contents(File.read('spec/fixtures/basic_testscript.json'))
    @patient = FHIR.from_contents(File.read('spec/fixtures/example_patient.json'))
    @runnable = described_class.new(@script.deep_dup)
  end

  describe '.handle_actions' do

  end
end