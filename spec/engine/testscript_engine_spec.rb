# frozen_string_literal: true

require_relative '../../lib/testscript_engine'

describe TestScriptEngine do
  before(:all) do
    input_path = "#{Dir.pwd}/spec/examples"
    @engine = TestScriptEngine.new('endpoint', 'input_path', 'output_path', {})
  end
  before(:each) do
    @engine.instance_variable_set(:@scripts, {})
    @engine.instance_variable_set(:@fixtures, {})
  end

  describe '.load_input' do
    it 'loads file if given file path' do
      @engine.input_path = "#{Dir.pwd}/spec/examples/basic_testscript.json"

      @engine.load_input

      expect(@engine.fixtures.keys.length).to be(0)
      expect(@engine.scripts.keys.length).to be(1)
    end

    context 'given non-fixture file' do
      context 'that is unreadable' do
        before do
          @engine.input_path = "#{Dir.pwd}/spec/examples/basic_testscript.json"
          allow(File).to receive(:read).and_raise(StandardError)
        end

        it 'stores nothing' do
          allow(@engine).to receive(:info)

          @engine.load_input

          expect(@engine.scripts.keys).to be_empty
          expect(@engine.fixtures.keys).to be_empty
          expect(@engine).to have_received(:info).with(:illegible_file)
        end
      end

      context 'that is non-FHIR' do
        before { @engine.input_path = "#{Dir.pwd}/spec/examples/non_resource.json" }

        it 'stores nothing' do
          allow(@engine).to receive(:info)

          @engine.load_input

          expect(@engine.scripts.keys).to be_empty
          expect(@engine.fixtures.keys).to be_empty
          expect(@engine).to have_received(:info).with(:non_fhir_contents)
        end
      end

      context 'that is poorly formed FHIR' do
        before { @engine.input_path = "#{Dir.pwd}/spec/examples/invalid_json.json" }

        it 'stores nothing' do
          allow(@engine).to receive(:info)

          @engine.load_input

          expect(@engine.scripts.keys).to be_empty
          expect(@engine.fixtures.keys).to be_empty
          expect(@engine).to have_received(:info).with(:non_fhir_contents)
        end
      end

      context 'that is non-TestScript resource' do
        before { @engine.input_path = "#{Dir.pwd}/spec/examples/basic_testreport.json" }

        it 'stores nothing' do
          allow(@engine).to receive(:info)

          @engine.load_input

          expect(@engine.scripts.keys).to be_empty
          expect(@engine.fixtures.keys).to be_empty
          expect(@engine).to have_received(:info).with(:non_testscript)
        end
      end

      context 'that is TestScript resource' do
        before { @engine.input_path = "#{Dir.pwd}/spec/examples/basic_testscript.json" }

        it 'stores resource' do
          @engine.load_input

          expect(@engine.fixtures).to be_empty
          expect(@engine.scripts.keys).to include('basic_testscript')
          expect(@engine.scripts['basic_testscript']).to eql(FHIR.from_contents(File.read(@engine.input_path)))
        end
      end
    end

    context 'given fixture file' do
      context 'that is unreadable' do
        before do
          @engine.input_path = "#{Dir.pwd}/spec/examples/fixtures/non_resource.json"
          allow(File).to receive(:read).and_raise(StandardError)
        end

        it 'stores nothing' do
          allow(@engine).to receive(:info)

          @engine.load_input

          expect(@engine.scripts.keys).to be_empty
          expect(@engine.fixtures.keys).to be_empty
          expect(@engine).to have_received(:info).with(:illegible_file)
        end
      end

      context 'that is non-FHIR' do
        before { @engine.input_path = "#{Dir.pwd}/spec/examples/fixtures/non_resource.json" }

        it 'stores nothing if non-FHIR unallowed' do
          allow(@engine).to receive(:info)

          @engine.load_input

          expect(@engine.scripts.keys).to be_empty
          expect(@engine.fixtures.keys).to be_empty
          expect(@engine).to have_received(:info).with(:non_fhir_contents)
        end

        it 'stores fixture if non-FHIR allowed' do
          @engine.nonfhir_fixture = true
          @engine.load_input

          expect(@engine.scripts.keys).to be_empty
          expect(@engine.fixtures.keys).to include('non_resource.json')
          expect(@engine.fixtures['non_resource']).to eql(FHIR.from_contents(File.read(@engine.input_path)))
        end
      end

      context 'that is a FHIR resource' do
        before { @engine.input_path = "#{Dir.pwd}/spec/examples/fixtures/basic_fixture_testscript.json" }

        it 'appropriately stores resource' do
          @engine.load_input

          expect(@engine.scripts).to be_empty
          expect(@engine.fixtures.keys).to include('basic_fixture_testscript.json')
          expect(@engine.fixtures['basic_fixture_testscript.json']).to eql(FHIR.from_contents(File.read(@engine.input_path)))
        end
      end
    end
  end
end