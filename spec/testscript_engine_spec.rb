# frozen_string_literal: true

require_relative '../lib/testscript_engine'

describe TestScriptEngine do
  before(:all) do
    input_path = File.join(Dir.pwd, "spec", "examples")
    @engine = TestScriptEngine.new('endpoint', 'input_path', 'output_path', {})
  end
  before(:each) do
    @engine.instance_variable_set(:@scripts, {})
    @engine.instance_variable_set(:@fixtures, {})
    @engine.instance_variable_set(:@profiles, {})
  end

  describe '.load_input' do
    it 'loads file if given file path' do
      @engine.input_path = File.join(Dir.pwd, "spec", "examples", "basic_testscript.json")

      @engine.load_input

      expect(@engine.fixtures.keys.length).to be(0)
      expect(@engine.scripts.keys.length).to be(1)
    end

    context 'given non-fixture file' do
      context 'that is unreadable' do
        before do
          @engine.input_path = File.join(Dir.pwd, "spec", "examples", "basic_testscript.json")
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
        before { @engine.input_path = File.join(Dir.pwd, "spec", "examples", "non_resource.json") }

        it 'stores nothing' do
          allow(@engine).to receive(:info)

          @engine.load_input

          expect(@engine.scripts.keys).to be_empty
          expect(@engine.fixtures.keys).to be_empty
          expect(@engine).to have_received(:info).with(:non_fhir_contents)
        end
      end

      context 'that is poorly formed FHIR' do
        before { @engine.input_path = File.join(Dir.pwd, "spec", "examples", "invalid_json.json") }

        it 'stores nothing' do
          allow(@engine).to receive(:info)

          @engine.load_input

          expect(@engine.scripts.keys).to be_empty
          expect(@engine.fixtures.keys).to be_empty
          expect(@engine).to have_received(:info).with(:non_fhir_contents)
        end
      end

      context 'that is non-TestScript resource' do
        before { @engine.input_path = File.join(Dir.pwd, "spec", "examples", "basic_testreport.json") }

        it 'stores nothing' do
          allow(@engine).to receive(:info)

          @engine.load_input

          expect(@engine.scripts.keys).to be_empty
          expect(@engine.fixtures.keys).to be_empty
          expect(@engine).to have_received(:info).with(:non_testscript)
        end
      end

      context 'that is TestScript resource' do
        before { @engine.input_path = File.join(Dir.pwd, "spec", "examples", "basic_testscript.json") }

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
          @engine.input_path = File.join(Dir.pwd, "spec", "examples", "fixtures" ,"non_resource.json")
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
        before { @engine.input_path = File.join(Dir.pwd, "spec", "examples", "fixtures" ,"non_resource.json") }

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
        before { @engine.input_path = File.join(Dir.pwd, "spec", "examples", "fixtures" ,"basic_fixture_testscript.json") }

        it 'appropriately stores resource' do
          @engine.load_input

          expect(@engine.scripts).to be_empty
          expect(@engine.fixtures.keys).to include('basic_fixture_testscript.json')
          expect(@engine.fixtures['basic_fixture_testscript.json']).to eql(FHIR.from_contents(File.read(@engine.input_path)))
        end
      end
    end
  end

  describe '.load_profiles' do

    context "Load profile StructureDefinition" do
      context "from file" do
        context "that exists" do
          context "and has a valid StructureDefinition" do
            before { 
              profile_list = ['spec/fixtures/structuredefinition-us-core-patient.json']
              @engine.instance_variable_set(:@options, {"profiles" => profile_list})
            }
            
            it "then the profile is available" do
              @engine.load_profiles
              expect(@engine.profiles.length).to eq(1)
              expect(@engine.profiles.key?("http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient")).to eq(true)
            end
          end

          context "and has a different FHIR resource type (e.g., patient)" do
            before { 
              profile_list = ['spec/fixtures/example_patient.json']
              @engine.instance_variable_set(:@options, {"profiles" => profile_list})
            }
            
            it "then the load fails" do
              expect{@engine.load_profiles}.to raise_error
            end
          end

          context "has non-FHIR content" do
            before { 
              profile_list = ['config.yml']
              @engine.instance_variable_set(:@options, {"profiles" => profile_list})
            }
            
            it "then the load fails" do
              expect{@engine.load_profiles}.to raise_error
            end
          end
        end

        context "that does not exist" do
          before { 
            profile_list = ['notafilename']
            @engine.instance_variable_set(:@options, {"profiles" => profile_list})
          }
          
          it "then the load fails" do
            expect{@engine.load_profiles}.to raise_error
          end
        end
      end

      context "from a web url" do
        context "that exists" do
          context "and has a valid StructureDefinition" do
            before { 
              profile_list = ['http://hl7.org/fhir/us/core/STU5.0.1/StructureDefinition-us-core-patient.json']
              @engine.instance_variable_set(:@options, {"profiles" => profile_list})
              structure_definition = File.read('spec/fixtures/structuredefinition-us-core-patient.json')
              stub_request(:get, "http://hl7.org/fhir/us/core/STU5.0.1/StructureDefinition-us-core-patient.json").
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
            
            it "then the profile is available" do
              @engine.load_profiles
              expect(@engine.profiles.length).to eq(1)
              expect(@engine.profiles.key?("http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient")).to eq(true)
            end
          end

          context "and has a different FHIR resource type (e.g., patient)" do
            before { 
              profile_list = ['http://hl7.org/fhir/us/core/STU5.0.1/Patient-example.json']
              @engine.instance_variable_set(:@options, {"profiles" => profile_list})
              not_structure_definition = File.read('spec/fixtures/example_patient.json')
              stub_request(:get, "http://hl7.org/fhir/us/core/STU5.0.1/Patient-example.json").
              with(
                headers: {
                   'Accept'=>'*/*',
                   'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                   'Content-Type'=>'application/json',
                   'Host'=>'hl7.org'
                   # 'User-Agent'=>'rest-client/2.1.0 (linux x86_64) ruby/2.7.3p183'
                  }).
              to_return(status: 200, body: not_structure_definition, headers: {})

            }
            
            it "then the load fails" do
              expect{@engine.load_profiles}.to raise_error
            end
          end

          context "has non-FHIR content" do
            before { 
              profile_list = ['http://hl7.org/fhir/us/core/STU5.0.1/StructureDefinition-us-core-patient.html']
              @engine.instance_variable_set(:@options, {"profiles" => profile_list})
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
              expect{@engine.load_profiles}.to raise_error
            end
          end
        end

        context "that does not exist" do
          before { 
            profile_list = ['http://hl7.org/fhir/us/core/STU5.0.1/notapage.zzz']
            @engine.instance_variable_set(:@options, {"profiles" => profile_list})
            stub_request(:get, "http://hl7.org/fhir/us/core/STU5.0.1/notapage.zzz").
              with(
                headers: {
                   'Accept'=>'*/*',
                   'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                   'Content-Type'=>'application/json',
                   'Host'=>'hl7.org'
                   # 'User-Agent'=>'rest-client/2.1.0 (linux x86_64) ruby/2.7.3p183'
                  }).
              to_return(status: 404, headers: {})

          }
          
          it "then the load fails" do
            expect{@engine.load_profiles}.to raise_error
          end
        end
      end
    end

    context "When using an external validator" do
      context "with existing profiles loaded" do
        before { 
          @engine.instance_variable_set(:@options, {"ext_validator" => "http://localhost/validatorapi"})
          stub_request(:get, "http://localhost/validatorapi/profiles").
            with(
              headers: {
                 'Accept'=>'*/*',
                 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                 'Content-Type'=>'application/json',
                 'Host'=>'localhost',
                 # 'User-Agent'=>'rest-client/2.1.0 (linux x86_64) ruby/2.7.3p183'
                }).
            to_return(status: 200, body: '["http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient"]', headers: {})

        }
        
        it "then the profile is available" do
          @engine.load_profiles
          expect(@engine.profiles.length).to eq(1)
          expect(@engine.profiles.key?("http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient")).to eq(true)

        end
      end

      context "when a profile load is needed" do
        context "and the load succeeds" do
          before { 
            profile_list = ['spec/fixtures/structuredefinition-us-core-patient.json']
            @engine.instance_variable_set(:@options, {"profiles" => profile_list, "ext_validator" => "http://localhost/validatorapi"})
            stub_request(:get, "http://localhost/validatorapi/profiles").
              with(
                headers: {
                   'Accept'=>'*/*',
                   'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                   'Content-Type'=>'application/json',
                   'Host'=>'localhost',
                   # 'User-Agent'=>'rest-client/2.1.0 (linux x86_64) ruby/2.7.3p183'
                  }).
              to_return(status: 200, body: '[]', headers: {})
            stub_request(:post, "http://localhost/validatorapi/profiles").
              with(
                headers: {
                   'Accept'=>'*/*',
                   'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                   'Content-Type'=>'application/json',
                   'Host'=>'localhost',
                   # 'User-Agent'=>'rest-client/2.1.0 (linux x86_64) ruby/2.7.3p183'
                  }).
              to_return(status: 200, headers: {})
  
          }
          
          it "then the profile is available" do
            @engine.load_profiles
            expect(@engine.profiles.length).to eq(1)
            expect(@engine.profiles.key?("http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient")).to eq(true)
  
          end
        end
        context "and the load fails" do
          before { 
            profile_list = ['spec/fixtures/structuredefinition-us-core-patient.json']
            @engine.instance_variable_set(:@options, {"profiles" => profile_list, "ext_validator" => "http://localhost/validatorapi"})
            stub_request(:get, "http://localhost/validatorapi/profiles").
              with(
                headers: {
                   'Accept'=>'*/*',
                   'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                   'Content-Type'=>'application/json',
                   'Host'=>'localhost',
                   # 'User-Agent'=>'rest-client/2.1.0 (linux x86_64) ruby/2.7.3p183'
                  }).
              to_return(status: 200, body: '[]', headers: {})
            stub_request(:post, "http://localhost/validatorapi/profiles").
              with(
                headers: {
                   'Accept'=>'*/*',
                   'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3',
                   'Content-Type'=>'application/json',
                   'Host'=>'localhost',
                   # 'User-Agent'=>'rest-client/2.1.0 (linux x86_64) ruby/2.7.3p183'
                  }).
              to_return(status: 400, headers: {})
  
          }
          
          it "then the load fails" do
            expect{@engine.load_profiles}.to raise_error
          end
        end
      end

    end

  end
end