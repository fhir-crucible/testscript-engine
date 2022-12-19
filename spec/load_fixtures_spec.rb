# frozen_string_literal: true
require_relative '../lib/testscript_engine/testscript_runnable'
require_relative '../lib/testscript_engine/output/message_handler'

describe TestScriptRunnable do
  before(:all) do
    @script = FHIR.from_contents(File.read('spec/examples/basic_testscript.json'))
    @patient = FHIR.from_contents(File.read('spec/examples/example_patient.json'))
    options = {"ext_validator" => nil, "ext_fhirpath" => nil}
    @runnable = described_class.new(@script.deep_dup, lambda { |k| {}[k] }, options)
  end

  before(:each) do
    @fixture = @script.fixture.first.deep_dup
    @runnable.autocreate.clear
  end

  describe '.load_fixtures' do
    it "given fixture without id logs warning" do
      @fixture.id = nil
      @runnable.script.fixture = [@fixture]

      expect(@runnable).to receive(:warning).with(:no_static_fixture_id)

      @runnable.load_fixtures

      expect(@runnable.autocreate).to be_empty
    end

    it "given fixture without resource logs warning" do
      @fixture.resource = nil
      @runnable.script.fixture = [@fixture]

      expect(@runnable).to receive(:warning).with(:no_static_fixture_resource)

      @runnable.load_fixtures

      expect(@runnable.autocreate).to be_empty
    end

    it 'given fixture with bad reference logs warning' do
      @runnable.script.fixture = [@fixture]

      @runnable.load_fixtures

      expect(@runnable.autocreate).to be_empty
      expect(@runnable.autodelete_ids).to be_empty
    end

    context 'given fixture with reference' do
      before do
        allow(@runnable).to receive(:get_fixture_from_ref).and_return(@patient)
      end

      it 'stores fixture' do
        @runnable.script.fixture = [@fixture]

        @runnable.load_fixtures

        expect(@patient).to be
        expect(@runnable.fixtures[@fixture.id]).to eq(@patient)
      end

      it 'denotes fixture for autocreation' do
        @runnable.script.fixture = [@fixture]

        @runnable.load_fixtures

        expect(@fixture.id).to be
        expect(@runnable.autocreate).to eq([@fixture.id])
      end

      it 'denotes fixture for autocreation' do
        @fixture.autodelete = true
        @runnable.script.fixture = [@fixture]

        @runnable.load_fixtures

        expect(@fixture.id).to be
        expect(@runnable.autocreate).to eq([@fixture.id])
        expect(@runnable.autodelete_ids).to eq([@fixture.id])
      end
    end
  end
end
