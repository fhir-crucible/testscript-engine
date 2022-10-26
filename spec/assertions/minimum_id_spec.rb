require_relative '../../lib/testscript_engine/assertion'
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
    @patient = FHIR.from_contents(File.read('spec/fixtures/example_patient.json'))
    @patient_min = FHIR.from_contents(File.read('spec/fixtures/example_patient_min.json'))
    url = 'https://example.com'
    header = { 'Content-Type' => 'Content-Type-value' }
    request = { method: :get, url: url, path: "Patient/123", headers: header }
    response = { code: 200, headers: header, body: patient.to_json }
    client = FHIR::Client.new(url)
    @client_reply = FHIR::ClientReply.new(request, response, client)
    @client_reply_min = FHIR::ClientReply.new(request, response, client)
    @client_reply.resource = patient
    @client_reply.response[:body] = patient
    @client_reply_min.resource = patient_min
    @client_reply_min.response[:body] = patient_min
    @tester.reply = @client_reply.deep_dup
    @assert = FHIR::TestScript::Setup::Action::Assert.new
    @tester.request_map = { @patient_id => @client_reply.request }
    @tester.response_map = { @patient_id => @client_reply.response, @patient_min_id => @client_reply_min.response }
    @tester.fixtures = { }
  end

  describe '.deep_merge' do
    context 'with same response and minimum fixture' do
      it 'merged result is same with response' do
        expect(@tester.deep_merge(@patient.to_hash, @patient.to_hash)).to eq(@patient.to_hash)
      end
    end

    context 'with same minimized response and minimized minimum fixture' do
      it 'merged result is same with minimized response' do
        expect(@tester.deep_merge(@patient_min.to_hash, @patient_min.to_hash)).to eq(@patient_min.to_hash)
      end
    end

    context 'with response supersedes minimium fixture' do
      it 'merged result is same with response' do
        expect(@tester.deep_merge(@patient.to_hash, @patient_min.to_hash)).to eq(@patient.to_hash)
      end
    end

    context 'with minimium fixture supersedes response' do
      it 'merged result is not same with minimized response' do
        expect(@tester.deep_merge(@patient_min.to_hash, @patient.to_hash)).not_to eq(@patient_min.to_hash)
      end
    end

  end

  describe '.minimum_id' do
    context 'with sourceId and minimumId' do
      before {      
        @assert.minimumId = @patient_min_id
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
        expect(@tester.minimum_id(@assert)).to eq(@tester.pass_message('minimumId', nil, nil, @assert.minimumId))
      end
    end

    context 'with only minimumId' do
      before {      
        @assert.minimumId = @patient_id
      }

      it 'minimum fixture is minimum of response' do
        expect(@tester.minimum_id(@assert)).to eq(@tester.pass_message('minimumId', nil, nil, @assert.minimumId))
      end
    end

  end

  
end