# frozen_string_literal: true
require 'TestScriptRunnable'

describe TestScriptRunnable do
  let(:json_resource) { FHIR::Patient.new.to_json }
  let(:resource) { FHIR.from_contents(json_resource) }
  let(:path) { '/local/path' }
  let(:fixture_id) { 'an_id' }
  let(:initial_ref) { 'reference' }
  let(:reference) { FHIR::Reference.new({ reference: initial_ref }) }
  let(:base_fixture) { { autocreate: true, autodelete: true, id: fixture_id, resource: reference } }
  let(:tScript_fixtures) { FHIR::TestScript::Fixture.new(base_fixture) }
  let(:tScript) { FHIR::TestScript.new({ fixture: [tScript_fixtures] }) }
  let(:runnable) { TestScriptRunnable.new(tScript) }

  describe '#load_fixture' do
    context 'when tScript.fixture is empty' do
      before { runnable.tScript.fixture = [] }

      it 'returns nil' do
        result = runnable.load_fixture
        expect(result).to eq(nil)
      end
    end

    context 'when tScript.fixture contains fixture(s)' do
      context 'with undefined id' do
        before { runnable.tScript.fixture[0].id = nil }

        it 'logs a warning and moves to next fixture' do
          expect(FHIR.logger).to receive(:warn).with '[.load_fixture] Fixture.id undefined. Can not store fixture. Continuing to next fixture.'

          runnable.load_fixture
        end
      end

      context 'with undefined resource' do
        before { runnable.tScript.fixture[0].resource = nil }

        it 'logs a warning and moves on to next fixture' do
          expect(FHIR.logger).to receive(:warn).with '[.load_fixture] Fixture.resource undefined. Can not create fixture without resource. Continuing to next fixture.'

          runnable.load_fixture
        end
      end

      context 'with defined resource' do
        context 'with wrong type' do
          before { runnable.tScript.fixture[0].resource = FHIR::Patient.new }

          it 'logs a warning and moves on to next fixture' do
            expect(FHIR.logger).to receive(:warn).with '[.load_fixture] Fixture.resource.reference can not be made into local reference. Can not store fixture. Continuing to next fixture.'

            runnable.load_fixture
          end
        end

        context 'with undefined reference' do
          before { runnable.tScript.fixture[0].resource.reference = nil }

          it 'logs a warning and moves on to next fixture' do
            expect(FHIR.logger).to receive(:warn).with '[.load_fixture] Fixture.resource.reference can not be made into local reference. Can not store fixture. Continuing to next fixture.'

            runnable.load_fixture
          end
        end

        context 'that refers to a contained resource' do
          before { runnable.tScript.fixture[0].resource.reference = '#contained' }

          context 'that can not be found' do
            it 'logs a warning and moves on to next fixture' do
              expect(FHIR.logger).to receive(:warn).with '[.load_fixture] Fixture.resource.reference can not be made into local reference. Can not store fixture. Continuing to next fixture.'

              runnable.load_fixture
            end
          end

          context 'that can be found' do
            before { runnable.tScript.contained << FHIR::Patient.new({ id: 'contained' }) }

            it 'stores the resource in fixtures @ fixture.id' do
              runnable.load_fixture
              expect(runnable.fixtures[fixture_id]).to eq(runnable.tScript.contained[0])
            end
          end
        end

        context 'that refers to an absolute url' do
          before { runnable.tScript.fixture[0].resource.reference = 'https://some_url.com' }

          it 'logs two warning and moves on to next fixture' do
            expect(FHIR.logger).to receive(:warn).with '[.get_resource_from_ref] Remote reference not supported: https://some_url.com. No reference extracted.'
            expect(FHIR.logger).to receive(:warn).with '[.load_fixture] Fixture.resource.reference can not be made into local reference. Can not store fixture. Continuing to next fixture.'

            runnable.load_fixture
          end
        end

        context 'that refers to a local reference' do
          before { runnable.tScript.fixture[0].resource.reference = path }

          context 'that a resource can not be extracted from' do
            it 'logs two warnings and moves onto next fixture' do
              expect(FHIR.logger).to receive(:warn).with '[.get_resource_from_ref] Error while loading local reference: No such file or directory @ rb_sysopen - /local/path. No reference extracted.'
              expect(FHIR.logger).to receive(:warn).with '[.load_fixture] Fixture.resource.reference can not be made into local reference. Can not store fixture. Continuing to next fixture.'
  
              runnable.load_fixture
            end
          end 

          context 'that a resource can be extracted from' do
            before do 
              allow(File).to receive(:open).and_return(json_resource)
              runnable.load_fixture
            end 

            it 'stores the resource in fixtures @ fixture.id' do
              expect(runnable.fixtures[fixture_id]).to eq(resource)
            end

            it 'adds fixture.id to autocreate, as appropriate' do
              expect runnable.autocreate.include? fixture_id
            end 

            it 'adds fixture.id to autodelete, as appropriate' do
              expect runnable.autodelete.include? fixture_id
            end 
          end 
        end
      end
    end
  end
end
