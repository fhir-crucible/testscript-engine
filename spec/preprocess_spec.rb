# frozen_string_literal: true

require 'TestScriptRunnable'

describe TestScriptRunnable do
  let(:fixtureId) { 'example' }
  let(:client) { FHIR::Client.new 'http://hapi.fhir.org/baseR4' }
  let(:script) { FHIR::TestScript.new (
    {
        "resourceType": 'TestScript',
        "url": 'http://hl7.org/fhir/TestScript/testscript-example-history/',
        "name": 'TestScript-Example-History',
        "status": 'draft',
        "fixture": [
            {
                "id": "fixture-patient-create",
                "autocreate": false,
                "autodelete": false,
                "resource": {
                    "reference": "Patient/example.json",
                    "display": "Peter Chalmers"
                }
            }
        ]
    }
)
}
let(:runnable) do
    TestScriptRunnable.new script
end

describe '#preprocessing' do
    context 'given autocreate true' do
        before {
            runnable.client client
            runnable.script.fixture[0].autocreate = true
            runnable.script.url = "../testscript-engine/TestScripts/TestScripts/"
        }

        it 'returns error while autocreation' do
            expect { runnable.preprocess }.to raise_error (WebMock::NetConnectNotAllowedError)
        end
    end

    context 'given autocreate false' do
        before {
            runnable.script.fixture[0].autocreate = false
            runnable.preprocess
        }

        it 'returns nothing since it doesn`t run any code' do
            expect(FHIR.logger).not_to receive(:info).with "[.load_fixture] Autocreate Fixture: #{fixtureId}"
        end
    end
end

describe '#postprocessing' do
    context 'given autodelete true' do
        before {
            runnable.client client
            runnable.script.fixture[0].autodelete = true
        }

        it 'returns error while autodeletion' do
            expect { runnable.postprocess }.to raise_error (NoMethodError)
        end
    end

    context 'given autodelete false' do
        before {
            runnable.script.fixture[0].autodelete = false
            runnable.postprocess
        }

        it 'returns nothing since it doesn`t run any code' do
            expect(FHIR.logger).not_to receive(:info).with "[.load_fixture] Autodelete Fixture: #{fixtureId}"
        end
    end
end

end