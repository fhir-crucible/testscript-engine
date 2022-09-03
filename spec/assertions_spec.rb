require 'Assertions'
require 'fhir_models'
require 'fhir_client'

class AssertionTestClass
  include Assertions
  attr_accessor :response_map, :fixtures

  def response_map
    @response_map
  end
end

describe Assertions do
  before(:each) do
    @assert = FHIR::TestScript::Setup::Action::Assert.new
  end
  before(:all) do
    @tester = AssertionTestClass.new
    @patient_id = 'patient_id'
    patient = FHIR.from_contents(File.read('spec/fixtures/example_patient.json'))
    url = 'https://example.com'
    request = { method: :get, url: url, path: "Patient/123" }
    response = { code: 200, headers: {}, body: patient.to_json }
    client = FHIR::Client.new(url)
    client_reply = FHIR::ClientReply.new(request, response, client)
    client_reply.resource = patient
    client_reply.response[:body] = patient
    @tester.response_map = { @patient_id => client_reply.response }
  end

  # TODO
  describe '.evaluate' do

  end

  describe '.determine_assert_type' do
    it 'returns content_type, if assert has contentType element' do
      @assert.contentType = 'contentType'

      expect(@tester.determine_assert_type(@assert.to_hash.keys)).to eq('content_type')
    end

    it 'returns expression, if assert has expression element' do
      @assert.expression = 'expression'

      expect(@tester.determine_assert_type(@assert.to_hash.keys)).to eq('expression')
    end

    it 'returns header_field, if assert has headerField element' do
      @assert.headerField = 'headerField'

      expect(@tester.determine_assert_type(@assert.to_hash.keys)).to eq('header_field')
    end

    it 'returns minimum_id, if assert has minimumId element' do
      @assert.minimumId = 'minimumId'

      expect(@tester.determine_assert_type(@assert.to_hash.keys)).to eq('minimum_id')
    end

    it 'returns navigation_links, if assert has navigationLinks element' do
      @assert.navigationLinks = 'navigationLinks'

      expect(@tester.determine_assert_type(@assert.to_hash.keys)).to eq('navigation_links')
    end

    it 'returns path, if assert has path element' do
      @assert.path = 'path'

      expect(@tester.determine_assert_type(@assert.to_hash.keys)).to eq('path')
    end

    it 'returns request_method, if assert has requestMethod element' do
      @assert.requestMethod = 'requestMethod'

      expect(@tester.determine_assert_type(@assert.to_hash.keys)).to eq('request_method')
    end

    it 'returns resource, if assert has resource element' do
      @assert.resource = 'resource'

      expect(@tester.determine_assert_type(@assert.to_hash.keys)).to eq('resource')
    end


    it 'returns response_code, if assert has responseCode element' do
      @assert.responseCode = 'responseCode'

      expect(@tester.determine_assert_type(@assert.to_hash.keys)).to eq('response_code')
    end

    it 'returns response, if assert has response element' do
      @assert.response = 'response'

      expect(@tester.determine_assert_type(@assert.to_hash.keys)).to eq('response')
    end

    it 'returns validate_profile_id, if assert has validateProfileId element' do
      @assert.validateProfileId = 'validateProfileId'

      expect(@tester.determine_assert_type(@assert.to_hash.keys)).to eq('validate_profile_id')
    end

    it 'returns request_url, if assert has requestURL element' do
      @assert.requestURL = 'requestURL'

      expect(@tester.determine_assert_type(@assert.to_hash.keys)).to eq('request_url')
    end
  end

  describe '.determine_expected_value' do
    it 'returns value, if assert has value element' do
      @assert.value = 'value'

      expect(@tester.determine_expected_value(@assert)).to eq('value')
    end

    it 'returns extracted expression value, if assert has compareToSourceExpression element' do
      @assert.compareToSourceId = @patient_id
      @assert.compareToSourceExpression = 'Patient.address.first().district'

      expect(@tester.determine_expected_value(@assert)).to eq('Rainbow')
    end

    it 'returns extracted path value, if assert has compareToSourcePath element' do
      @assert.compareToSourceId = @patient_id
      @assert.compareToSourcePath = 'fhir:Patient/fhir:address/fhir:district/@value'

      expect(@tester.determine_expected_value(@assert)).to eq('Rainbow')
    end
  end

  describe 'compare' do
    context "given 'equals' operator" do
      let(:assert_type) { 'Response Code' }
      let(:operator) { 'equals' }

      it 'returns pass message if received and expected are equal' do
        received = 0
        expected = 0
        message = @tester.compare(assert_type, received, operator, expected)

        expect(message).to eq(@tester.pass_message(assert_type, received, 'equals', expected))
      end

      it 'returns fail message if received and expected are not equal' do
        received = 1
        expected = 0
        message = @tester.compare(assert_type, received, operator, expected)

        expect(message).to eq(@tester.fail_message(assert_type, received, 'equals', expected))
      end
    end

    context "given 'notEquals' operator" do
      let(:assert_type) { 'Response Code' }
      let(:operator) { 'notEquals' }

      it 'returns pass message if received and expected are not equal' do
        received = 1
        expected = 0
        message = @tester.compare(assert_type, received, operator, expected)

        expect(message).to eq(@tester.pass_message(assert_type, received, 'did not equal', expected))
      end

      it 'returns fail message if received and expected are equal' do
        received = 0
        expected = 0
        message = @tester.compare(assert_type, received, operator, expected)

        expect(message).to eq(@tester.fail_message(assert_type, received, 'did not equal', expected))
      end
    end

    context "given 'in' operator" do
      let(:assert_type) { 'Response Code' }
      let(:operator) { 'in' }

      it 'returns pass message if received in expected' do
        received = 0
        expected = [0]
        message = @tester.compare(assert_type, received, operator, expected)

        expect(message).to eq(@tester.pass_message(assert_type, received, 'in', expected))
      end

      it 'returns fail message if received not in expected' do
        received = 1
        expected = [0]
        message = @tester.compare(assert_type, received, operator, expected)

        expect(message).to eq(@tester.fail_message(assert_type, received, 'be in', expected))
      end
    end

    context "given 'notIn' operator" do
      let(:assert_type) { 'Response Code' }
      let(:operator) { 'notIn' }

      it 'returns pass message if received not in expected' do
        received = 1
        expected = [0]
        message = @tester.compare(assert_type, received, operator, expected)

        expect(message).to eq(@tester.pass_message(assert_type, received, 'not in', expected))
      end

      it 'returns fail message if received in expected' do
        received = 0
        expected = [0]
        message = @tester.compare(assert_type, received, operator, expected)

        expect(message).to eq(@tester.fail_message(assert_type, received, 'not be in', expected))
      end
    end

    context "given 'greaterThan' operator" do
      let(:assert_type) { 'Response Code' }
      let(:operator) { 'greaterThan' }

      it 'returns pass message if received > expected' do
        received = 1
        expected = 0
        message = @tester.compare(assert_type, received, operator, expected)

        expect(message).to eq(@tester.pass_message(assert_type, received, 'greater than', expected))
      end

      it 'returns fail message if received not > expected' do
        received = 0
        expected = 0
        message = @tester.compare(assert_type, received, operator, expected)

        expect(message).to eq(@tester.fail_message(assert_type, received, 'be greater than', expected))
      end
    end

    context "given 'lessThan' operator" do
      let(:assert_type) { 'Response Code' }
      let(:operator) { 'lessThan' }

      it 'returns pass message if received < expected' do
        received = 0
        expected = 1
        message = @tester.compare(assert_type, received, operator, expected)

        expect(message).to eq(@tester.pass_message(assert_type, received, 'less than', expected))
      end

      it 'returns fail message if received not < expected' do
        received = 0
        expected = 0
        message = @tester.compare(assert_type, received, operator, expected)

        expect(message).to eq(@tester.fail_message(assert_type, received, 'be less than', expected))
      end
    end

    context "given 'empty' operator" do
      let(:assert_type) { 'Response Code' }
      let(:operator) { 'empty' }

      it 'returns pass message if received empty' do
        received = []
        message = @tester.compare(assert_type, received, operator, nil)

        expect(message).to eq(@tester.pass_message(assert_type, received, 'empty', nil))
      end

      it 'returns fail message if received not empty' do
        received = 0
        message = @tester.compare(assert_type, received, operator, nil)

        expect(message).to eq(@tester.fail_message(assert_type, received, 'be empty', nil))
      end
    end

    context "given 'notEmpty' operator" do
      let(:assert_type) { 'Response Code' }
      let(:operator) { 'notEmpty' }

      it 'returns pass message if received not empty' do
        received = [1]
        message = @tester.compare(assert_type, received, operator, nil)

        expect(message).to eq(@tester.pass_message(assert_type, received, 'not empty', nil))
      end

      it 'returns fail message if received empty' do
        received = []
        message = @tester.compare(assert_type, received, operator, nil)

        expect(message).to eq(@tester.fail_message(assert_type, received, 'not be empty', nil))
      end
    end

    context "given 'contains' operator" do
      let(:assert_type) { 'Response Code' }
      let(:operator) { 'contains' }

      it 'returns pass message if received contains expected' do
        received = [1]
        expected = 1
        message = @tester.compare(assert_type, received, operator, expected)

        expect(message).to eq(@tester.pass_message(assert_type, received, 'contains', expected))
      end

      it 'returns fail message if received does not contain expected' do
        received = nil
        expected = 1
        message = @tester.compare(assert_type, received, operator, expected)

        expect(message).to eq(@tester.fail_message(assert_type, received, 'contain', expected))
      end
    end

    context "given 'notContains' operator" do
      let(:assert_type) { 'Response Code' }
      let(:operator) { 'notContains' }

      it 'returns pass message if received does not contain expected' do
        received = []
        expected = 1
        message = @tester.compare(assert_type, received, operator, expected)

        expect(message).to eq(@tester.pass_message(assert_type, received, 'did not contain', expected))
      end

      it 'returns fail message if received does contain expected' do
        received = [0]
        expected = 0
        message = @tester.compare(assert_type, received, operator, expected)

        expect(message).to eq(@tester.fail_message(assert_type, received, 'not contain', expected))
      end
    end
  end
end