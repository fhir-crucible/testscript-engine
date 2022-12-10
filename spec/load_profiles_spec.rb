# frozen_string_literal: true
require_relative '../lib/testscript_engine/testscript_runnable'
require_relative '../lib/testscript_engine/output/message_handler'

describe TestScriptRunnable do
  before(:all) do
    @structure_definition = File.read('spec/fixtures/structuredefinition-us-core-patient.json')
    @script = FHIR.from_contents(File.read('spec/examples/basic_testscript_profile.json'))

    stub_request(:get, "http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient").
      with(
        headers: {
       	  'Accept'=>'*/*',
       	  'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
       	  'Content-Type'=>'application/json',
       	  'Host'=>'hl7.org'
       	  # 'User-Agent'=>'rest-client/2.1.0 (linux x86_64) ruby/2.7.3p183'
          }).
    to_return(status: 200, body: "#{@structure_definition}", headers: {})
         
    options = {"ext_validator" => nil, "ext_fhirpath" => nil}
    @runnable = described_class.new(@script, lambda { |k| {}[k] }, options)
  end

  describe '.load_profiles' do
    
    context "given profile with proper id and reference" do
      it "returns profile id" do
        expect(@runnable.load_profiles[0].id).to eq("patient-profile")
      end
    end

    context "given profile without id" do
      before { @runnable.script.profile[0].id = nil }

      it "returns null" do
        expect(@runnable.load_profiles[0].id).to eq(nil)
      end
    end

    context "given profile without content" do
      before { @runnable.script.profile[0].reference = nil }

      it "returns null" do
        expect(@runnable.load_profiles[0].id).to eq(nil)
        expect(@runnable.load_profiles[0].reference).to eq(nil)
      end
    end
    
  end
end
