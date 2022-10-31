# frozen_string_literal: true
require_relative '../../lib/testscript_engine/testscript_runnable'
require_relative '../../lib/testscript_engine/message_handler'

describe TestScriptRunnable do
  before(:all) do
    @script = FHIR.from_contents(File.read('spec/fixtures/basic_testscript.json'))
    @patient = FHIR.from_contents(File.read('spec/fixtures/example_patient.json'))
    @patient_uscore = FHIR.from_contents(File.read('spec/fixtures/example_patient_uscore.json'))
    @patient_profile = FHIR.from_contents(File.read('spec/fixtures/structuredefinition-us-core-patient.json'))
    @runnable = described_class.new(@script)
    @runnable.fixtures['patient'] = @patient
    @runnable.fixtures['patient_uscore'] = @patient_uscore
    @runnable.profiles['patient_profile_id'] = @patient_profile

    @assert = FHIR::TestScript::Setup::Action::Assert.new

  end

  describe '.validate_profile_id' do
    before {    
      @assert.validateProfileId = 'patient_profile_id'
    }

    it "give resource comforms to profile" do
      @assert.sourceId = 'patient_uscore'
      expect(@runnable.validate_profile_id(@assert)).to eq(@runnable.compare("validateProfileId", @assert.sourceId, 'isProfileOf', @assert.validateProfileId))
    end
  end

    
  describe '.compare' do
      before {    
        @assert.validateProfileId = 'patient_profile_id'
      }
  
      it "give resource comforms to profile" do
        @assert.sourceId = 'patient_uscore'
        expect(@runnable.compare("validateProfileId", @assert.sourceId, 'isProfileOf', @assert.validateProfileId)).to eq(@runnable.pass_message("validateProfileId", @assert.sourceId, 'isProfileOf', @assert.validateProfileId))
      end
  end

end
