require 'TestScriptRunnable'

describe TestScriptRunnable do
  let(:requestId) { 'requestId' }
  let(:client) { FHIR::Client.new 'https://example.com' }
  let(:resource) { FHIR::AllergyIntolerance.new }
  let(:resourceResponse) { { :code => 200, :headers => {}, :body => resource.to_json } }
  let(:resourceReply) { FHIR::ClientReply.new(nil, resourceResponse, client) }
  let(:nonResourceResponse) { { :code => 200, :headers => {}, :body => 'body' } }
  let(:nonResourceReply) { FHIR::ClientReply.new(nil, nonResourceResponse, client) }
  let(:requestType) { :get }
  let(:operation) { FHIR::TestScript::Setup::Action::Operation.new }
  let(:runnable) {
    TestScriptRunnable.new FHIR::TestScript.new(
      {
        "resourceType": 'TestScript',
        "url": 'http://hl7.org/fhir/TestScript/testscript-example-history',
        "name": 'TestScript-Example-History',
        "status": 'draft'
      }
    )
  }

  context '#storage' do
    context 'gives fresh client.reply' do

    end 
  end 
end 