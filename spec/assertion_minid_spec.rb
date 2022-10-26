require_relative '../lib/testscript_engine/assertion'
require 'fhir_models'
require 'fhir_client'

class AssertionTestClass
  include Assertion
  attr_accessor :response_map, :request_map, :fixtures, :reply

  def response_map
    @response_map
  end

  def request_map
    @request_map
  end

  def reply
    @reply
  end

  def evaluate_expression(input, resource)
    FHIRPath.evaluate(input, resource.to_hash)
  end
end

describe Assertion do
  before(:each) do
    @tester = AssertionTestClass.new
    @patient_id = 'patient_id'
    @patient_min_id = 'patient_min_id'

    patient = FHIR.from_contents(File.read('spec/fixtures/example_patient.json'))
    patient_min = FHIR.from_contents(File.read('spec/fixtures/example_patient_min.json'))
    url = 'https://example.com'
    header = { 'Content-Type' => 'Content-Type-value' }
    request = { method: :get, url: url, path: "Patient/123", headers: header }
    response = { code: 200, headers: header, body: patient.to_json }
    client = FHIR::Client.new(url)
    @client_reply = FHIR::ClientReply.new(request, response, client)
    @client_reply.resource = patient
    @client_reply.response[:body] = patient
    @tester.reply = @client_reply.deep_dup
    @assert = FHIR::TestScript::Setup::Action::Assert.new
    @tester.request_map = { @patient_id => @client_reply.request }
    @tester.response_map = { @patient_id => @client_reply.response }
    @tester.fixtures = { @patient_min_id => patient_min }
  end

  describe '.determine_assert_type' do
    it 'returns minimum_id, if assert has minimumId element' do
      @assert.minimumId = 'minimumId'

      expect(@tester.determine_assert_type(@assert.to_hash.keys)).to eq('minimum_id')
    end
  end

  describe '.minimum_id' do
    context 'with sourceId and minimumId' do
      before {      
        @assert.minimumId = @patient_id
        @assert.sourceId = @patient_id
      }
      
      it 'minimum fixture is minimum of response' do
        expect(@tester.minimum_id(@assert)).to eq(@tester.pass_message('minimumId', nil, nil, @assert.minimumId))
        
      end
    end

    context 'with sourceId and minimumId' do
      before {      
        @assert.minimumId = @patient_id
        @assert.sourceId = @patient_min_id
      }
      
      it 'minimum fixture is minimum of response' do
        expect(@tester.minimum_id(@assert)).to eq(@tester.fail_message('minimumId', nil, nil, @assert.minimumId))
        
      end
    end
  end

  
end