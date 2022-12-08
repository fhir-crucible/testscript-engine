# frozen_string_literal: true
require_relative '../../lib/testscript_engine/testscript_runnable'
require_relative '../../lib/testscript_engine/message_handler'

describe TestScriptRunnable do
  before(:all) do
    @script = FHIR.from_contents(File.read('spec/examples/basic_testscript.json'))
    @patient_nonuscore = FHIR.from_contents(File.read('spec/fixtures/patient_example_non_uscore.json'))
    @patient_uscore = FHIR.from_contents(File.read('spec/fixtures/patient_example_uscore.json'))
    @sd_uscore = FHIR.from_contents(File.read('spec/fixtures/structuredefinition-us-core-patient.json'))

    @runnable = TestScriptRunnable.new(@script, lambda { |k| {}[k] })
    @runnable.fixtures['patient_nonuscore'] = @patient_nonuscore
    @runnable.fixtures['patient_uscore'] = @patient_uscore
    @runnable.profiles['patient_profile_id'] = @sd_uscore

    @assert = FHIR::TestScript::Setup::Action::Assert.new

  end

  describe '.validate_profile_id' do
    before {    
      @assert.validateProfileId = 'patient_profile_id'
    }

    context "give resource comforms to profile" do
      it 'returns true' do
        @assert.sourceId = 'patient_uscore'
        expect(@runnable.validate_profile_id(@assert)).to eq(true)
      end
    end

    context "give resource doesn't comform to profile" do
      it 'returns true' do
        @assert.sourceId = 'patient_nonuscore'
        expect(@runnable.validate_profile_id(@assert)).to eq(false)
      end

    end

  end

end