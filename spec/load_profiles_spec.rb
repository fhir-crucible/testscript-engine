# frozen_string_literal: true
require_relative '../lib/testscript_engine/testscript_runnable'
require_relative '../lib/testscript_engine/output/message_handler'

describe TestScriptRunnable do
  before(:all) do
    # @sd = FHIR.from_contents(File.read('spec/examples/StructureDefinition-us-core-patient.json'))
    @structure_definition = File.read('spec/examples/StructureDefinition-us-core-patient.json')

    stub_request(:get, "http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient").
    with(
      headers: {
      'Accept'=>'*/*',
      'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
      'Content-Type'=>'application/json',
      'Host'=>'hl7.org',
      'User-Agent'=>'rest-client/2.1.0 (darwin21.5.0 x86_64) ruby/2.7.2p137'
      }).
    to_return(status: 200, body: "#{@structure_definition}", headers: {})

    @script = FHIR.from_contents(File.read('spec/examples/basic_testscript.json'))
    @patient = FHIR.from_contents(File.read('spec/examples/example_patient.json'))
    @runnable = described_class.new(@script.deep_dup, lambda { |k| {}[k] })
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