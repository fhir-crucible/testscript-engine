# frozen_string_literal: true

require 'TestScriptRunnable'

describe TestScriptRunnable do
  let(:request_type) { :post }
  let(:targetId) { 'patient-search' }
  let(:sourceId) { 'fixture-patient-create' }
  let(:resource) { FHIR::AllergyIntolerance.new }
  let(:client) { FHIR::Client.new 'https://example.com' }
  let(:clientReply) { FHIR::ClientReply.new(nil, nil, client) }
  let(:operation) { FHIR::TestScript::Setup::Action::Operation.new }
  let(:script) { FHIR::TestScript.new (
    {
        "resourceType": 'TestScript',
        "url": 'http://hl7.org/fhir/TestScript/testscript-example-history',
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
            runnable.script.fixture[0].autocreate = true
        }

        it 'returns nil' do
            expect(runnable.preprocess).to raise_error
        end
    end

    context 'given autocreate false' do
        before {
            runnable.script.fixture[0].autocreate = false
            runnable.preprocess
        }

        it 'returns nil' do
            expect(runnable.id_map["fixture-patient-create"]).to eq(nil)
        end
    end
end

describe '#postprocessing' do
    context 'given autodelete true' do
        before {
            runnable.script.fixture[0].autodelete = true
        }

        it 'returns nil' do
            expect(runnable.postprocess).to raise_error
        end
    end

    context 'given autodelete false' do
        before {
            runnable.script.fixture[0].autodelete = false
            runnable.postprocess
        }

        it 'returns nil' do
            expect(runnable.id_map["fixture-patient-create"]).to eq(nil)
        end
    end
end

end