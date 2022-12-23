# frozen_string_literal: true
require_relative '../lib/testscript_engine/testscript_runnable'
require_relative '../lib/testscript_engine/message_handler'

describe TestScriptRunnable do
  before(:all) do
    @structure_definition = FHIR.from_contents(File.read('spec/profiles/structuredefinition-us-core-patient.json'))
    @script = FHIR.from_contents(File.read('spec/examples/basic_testscript_profile.json'))
    @available_profiles = { "http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient" => @structure_definition}
    options = {"ext_validator" => nil, "ext_fhirpath" => nil}
    @runnable = described_class.new(@script, lambda { |k| {}[k] }, options, @available_profiles)
  end

  describe '.load_profiles' do
    
    context "given profile with proper id and reference" do
      context "and a pre-loaded profile definition" do
        before { 
          @runnable.script.profile[0].id = "patient-profile"
          @runnable.script.profile[0].reference = "http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient" 
          @runnable.profiles.clear
          @runnable.instance_variable_set(:@available_profiles, @available_profiles)
        }
        
        it "then the load succeeds" do
          @runnable.load_profiles
          expect(@runnable.profiles.length).to eq(1)
          expect(@runnable.profiles["patient-profile"].url).to eq("http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient")
        end
      end

      context "and no loaded profile definition" do
        context "and a canonical url that resolves to the StructureDefinition" do
          before { 
            @runnable.script.profile[0].id = "patient-profile"
            @runnable.script.profile[0].reference = "http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient" 
            @runnable.profiles.clear
            @runnable.instance_variable_set(:@available_profiles, {})

            structure_definition = File.read('spec/profiles/structuredefinition-us-core-patient.json')
              stub_request(:get, "http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient").
              with(
                headers: {
                   'Accept'=>'*/*',
                   'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                   'Content-Type'=>'application/json',
                   'Host'=>'hl7.org'
                   # 'User-Agent'=>'rest-client/2.1.0 (linux x86_64) ruby/2.7.3p183'
                  }).
              to_return(status: 200, body: structure_definition, headers: {})
          }
          
          it "then the load succeeds" do
            @runnable.load_profiles
            expect(@runnable.profiles.length).to eq(1)
            expect(@runnable.profiles["patient-profile"].url).to eq("http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient")
          end
        end

        context "and a canonical url that does not resolve to a StructureDefinition" do
          before { 
            @runnable.script.profile[0].id = "patient-profile"
            @runnable.script.profile[0].reference = "http://hl7.org/fhir/StructureDefinition/Patient" 
            @runnable.profiles.clear
            @runnable.instance_variable_set(:@available_profiles, {})
            not_fhir = File.read('config.yml')
              stub_request(:get, "http://hl7.org/fhir/us/core/STU5.0.1/Patient-example.json").
              with(
                headers: {
                   'Accept'=>'*/*',
                   'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                   'Content-Type'=>'application/json',
                   'Host'=>'hl7.org'
                   # 'User-Agent'=>'rest-client/2.1.0 (linux x86_64) ruby/2.7.3p183'
                  }).
              to_return(status: 200, body: not_fhir, headers: {})
          }
          
          it "then the load fails" do
            expect{@runnable.load_profiles}.to raise_error
          end
        end
      end
    end

    context "given profile without id" do
      before { 
        @runnable.script.profile[0].id = nil 
        @runnable.script.profile[0].reference = "http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient" 
        @runnable.profiles.clear
      }

      it "then the profile is not available" do
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

      it "then the profile is not available" do
        @runnable.load_profiles
        expect(@runnable.profiles.length).to eq(0)
      end
    end
    
  end
end
