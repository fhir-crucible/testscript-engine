# frozen_string_literal: true
require_relative '../lib/testscript_engine/testscript_runnable'
require_relative '../lib/testscript_engine/message_handler'

describe TestScriptRunnable do
  before(:all) do
    @structure_definition = FHIR.from_contents(File.read('spec/profiles/structuredefinition-us-core-patient.json'))
    @script = FHIR.from_contents(File.read('spec/examples/basic_testscript_profile.json'))
    available_profiles = { "http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient" => @structure_definition}
    options = {"ext_validator" => nil, "ext_fhirpath" => nil}
    @runnable = described_class.new(@script, lambda { |k| {}[k] }, options, available_profiles)
  end

  describe '.load_profiles' do
    
    context "given profile with proper id and reference" do
      before { 
        @runnable.script.profile[0].id = "patient-profile"
        @runnable.script.profile[0].reference = "http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient" 
        @runnable.profiles.clear
      }
      
      it "returns profile id" do
        @runnable.load_profiles
        expect(@runnable.profiles.length).to eq(1)
        expect(@runnable.profiles["patient-profile"].url).to eq("http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient")
      end
    end

    context "given profile without id" do
      before { 
        @runnable.script.profile[0].id = nil 
        @runnable.script.profile[0].reference = "http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient" 
        @runnable.profiles.clear
      }

      it "returns null" do
        @runnable.load_profiles
        expect(@runnable.profiles.length).to eq(0)
      end
    end

    context "given profile without reference" do
      before { 
        @runnable.script.profile[0].id = "patient-profile"
        @runnable.script.profile[0].reference = nil 
        @runnable.profiles.clear
      }

      it "returns null" do
        @runnable.load_profiles
        expect(@runnable.profiles.length).to eq(0)
      end
    end
    
  end
end
