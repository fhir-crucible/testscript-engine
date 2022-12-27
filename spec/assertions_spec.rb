require_relative '../lib/testscript_engine/assertion'

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

  def replace_variables(value)
    return value
  end
end

describe Assertion do
  before(:each) do
    @tester = AssertionTestClass.new
    @patient_id = 'patient_id'
    patient = FHIR.from_contents(File.read('spec/fixtures/patient_example.json'))
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
    @tester.fixtures = {}
  end

  # TODO
  describe '.evaluate' do

  end

  describe '.determine_assert_type' do
    it 'returns content_type, if assert has contentType element' do
      @assert.contentType = 'contentType'

      expect(@tester.determine_assert_type(@assert)).to eq('content_type')
    end

    it 'returns expression, if assert has expression element' do
      @assert.expression = 'expression'

      expect(@tester.determine_assert_type(@assert)).to eq('expression')
    end

    it 'returns header_field, if assert has headerField element' do
      @assert.headerField = 'headerField'

      expect(@tester.determine_assert_type(@assert)).to eq('header_field')
    end

    it 'returns minimum_id, if assert has minimumId element' do
      @assert.minimumId = 'minimumId'

      expect(@tester.determine_assert_type(@assert)).to eq('minimum_id')
    end

    it 'returns navigation_links, if assert has navigationLinks element' do
      @assert.navigationLinks = 'navigationLinks'

      expect(@tester.determine_assert_type(@assert)).to eq('navigation_links')
    end

    it 'returns path, if assert has path element' do
      @assert.path = 'path'

      expect(@tester.determine_assert_type(@assert)).to eq('path')
    end

    it 'returns request_method, if assert has requestMethod element' do
      @assert.requestMethod = 'requestMethod'

      expect(@tester.determine_assert_type(@assert)).to eq('request_method')
    end

    it 'returns resource, if assert has resource element' do
      @assert.resource = 'resource'

      expect(@tester.determine_assert_type(@assert)).to eq('resource')
    end


    it 'returns response_code, if assert has responseCode element' do
      @assert.responseCode = 'responseCode'

      expect(@tester.determine_assert_type(@assert)).to eq('response_code')
    end

    it 'returns response, if assert has response element' do
      @assert.response = 'response'

      expect(@tester.determine_assert_type(@assert)).to eq('response')
    end

    it 'returns validate_profile_id, if assert has validateProfileId element' do
      @assert.validateProfileId = 'validateProfileId'

      expect(@tester.determine_assert_type(@assert)).to eq('validate_profile_id')
    end

    it 'returns request_url, if assert has requestURL element' do
      @assert.requestURL = 'requestURL'

      expect(@tester.determine_assert_type(@assert)).to eq('request_url')
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

  describe '.compare' do
    context "given 'equals' operator" do
      let(:assert_type) { 'Response Code' }
      let(:operator) { 'equals' }

      it 'returns pass message if received and expected are equal' do
        received = 0
        expected = 0
        message = @tester.compare(assert_type, received, operator, expected)

        expect(message).to eq(@tester.pass_message(assert_type, received, operator, expected))
      end

      it 'returns fail message if received and expected are not equal' do
        received = 1
        expected = 0

        expect { @tester.compare(assert_type, received, operator, expected) }
          .to raise_exception(Assertion::AssertionException, @tester.fail_message(assert_type, received, operator, expected))
      end
    end

    context "given 'notEquals' operator" do
      let(:assert_type) { 'Response Code' }
      let(:operator) { 'notEquals' }

      it 'returns pass message if received and expected are not equal' do
        received = 1
        expected = 0
        message = @tester.compare(assert_type, received, operator, expected)

        expect(message).to eq(@tester.pass_message(assert_type, received, operator, expected))
      end

      it 'returns fail message if received and expected are equal' do
        received = 0
        expected = 0

        expect { @tester.compare(assert_type, received, operator, expected) }
          .to raise_exception(Assertion::AssertionException, @tester.fail_message(assert_type, received, operator, expected))
      end
    end

    context "given 'in' operator" do
      let(:assert_type) { 'Response Code' }
      let(:operator) { 'in' }

      it 'returns pass message if received in expected' do
        received = "0"
        expected = "0"
        message = @tester.compare(assert_type, received, operator, expected)

        expect(message).to eq(@tester.pass_message(assert_type, received, operator, expected))
      end

      it 'returns fail message if received not in expected' do
        received = 1
        expected = [0]

        expect { @tester.compare(assert_type, received, operator, expected) }
          .to raise_exception(Assertion::AssertionException, @tester.fail_message(assert_type, received, operator, expected))
      end
    end

    context "given 'notIn' operator" do
      let(:assert_type) { 'Response Code' }
      let(:operator) { 'notIn' }

      it 'returns pass message if received not in expected' do
        received = "1"
        expected = "0"
        message = @tester.compare(assert_type, received, operator, expected)

        expect(message).to eq(@tester.pass_message(assert_type, received, operator, expected))
      end

      it 'returns fail message if received in expected' do
        received = "0"
        expected = "0"

        expect { @tester.compare(assert_type, received, operator, expected) }
          .to raise_exception(Assertion::AssertionException, @tester.fail_message(assert_type, received, operator, expected))
      end
    end

    context "given 'greaterThan' operator" do
      let(:assert_type) { 'Response Code' }
      let(:operator) { 'greaterThan' }

      it 'returns pass message if received > expected' do
        received = 1
        expected = 0
        message = @tester.compare(assert_type, received, operator, expected)

        expect(message).to eq(@tester.pass_message(assert_type, received, operator, expected))
      end

      it 'returns fail message if received not > expected' do
        received = 0
        expected = 0

        expect { @tester.compare(assert_type, received, operator, expected) }
          .to raise_exception(Assertion::AssertionException, @tester.fail_message(assert_type, received, operator, expected))
      end
    end

    context "given 'lessThan' operator" do
      let(:assert_type) { 'Response Code' }
      let(:operator) { 'lessThan' }

      it 'returns pass message if received < expected' do
        received = 0
        expected = 1
        message = @tester.compare(assert_type, received, operator, expected)

        expect(message).to eq(@tester.pass_message(assert_type, received, operator, expected))
      end

      it 'returns fail message if received not < expected' do
        received = 0
        expected = 0

        expect { @tester.compare(assert_type, received, operator, expected) }
          .to raise_exception(Assertion::AssertionException, @tester.fail_message(assert_type, received, operator, expected))
      end
    end

    context "given 'empty' operator" do
      let(:assert_type) { 'Response Code' }
      let(:operator) { 'empty' }

      it 'returns pass message if received empty' do
        received = []
        message = @tester.compare(assert_type, received, operator, nil)

        expect(message).to eq(@tester.pass_message(assert_type, received, operator, nil))
      end

      it 'returns fail message if received not empty' do
        received = 0
        expect { @tester.compare(assert_type, received, operator, nil) }
          .to raise_exception(Assertion::AssertionException, @tester.fail_message(assert_type, received, operator, nil))
      end
    end

    context "given 'notEmpty' operator" do
      let(:assert_type) { 'Response Code' }
      let(:operator) { 'notEmpty' }

      it 'returns pass message if received not empty' do
        received = [1]
        message = @tester.compare(assert_type, received, operator, nil)

        expect(message).to eq(@tester.pass_message(assert_type, received, operator, nil))
      end

      it 'returns fail message if received empty' do
        received = []
        expect { @tester.compare(assert_type, received, operator, nil) }
          .to raise_exception(Assertion::AssertionException, @tester.fail_message(assert_type, received, operator, nil))
      end
    end

    context "given 'contains' operator" do
      let(:assert_type) { 'Response Code' }
      let(:operator) { 'contains' }

      it 'returns pass message if received contains expected' do
        received = [1]
        expected = 1
        message = @tester.compare(assert_type, received, operator, expected)

        expect(message).to eq(@tester.pass_message(assert_type, received, operator, expected))
      end

      it 'returns fail message if received does not contain expected' do
        received = nil
        expected = 1
        expect { @tester.compare(assert_type, received, operator, expected) }
          .to raise_exception(Assertion::AssertionException, @tester.fail_message(assert_type, received, operator, expected))
      end
    end

    context "given 'notContains' operator" do
      let(:assert_type) { 'Response Code' }
      let(:operator) { 'notContains' }

      it 'returns pass message if received does not contain expected' do
        received = []
        expected = 1
        message = @tester.compare(assert_type, received, operator, expected)

        expect(message).to eq(@tester.pass_message(assert_type, received, operator, expected))
      end

      it 'returns fail message if received does contain expected' do
        received = [0]
        expected = 0
        expect { @tester.compare(assert_type, received, operator, expected) }
          .to raise_exception(Assertion::AssertionException, @tester.fail_message(assert_type, received, operator, expected))
      end
    end
  end

  describe '.response_header' do
    it 'uses header from response_map matching ID' do
      result = @tester.response_header(@patient_id, 'Content-Type')

      expect(result).to eq('Content-Type-value')
    end

    it 'returns nil if no response_map matching ID' do
      @tester.response_map = {}

      result = @tester.response_header(@patient_id, 'Content-Type')

      expect(result).to be(nil)
    end

    it 'returns nil if no headers in response' do
      @tester.response_map[@patient_id].delete(:headers)

      result = @tester.response_header(@patient_id, 'Content-Type')

      expect(result).to be(nil)
    end

    it 'returns nil if header_name input and no match in request headers' do
      result = @tester.response_header(@patient_id, 'unmatched-header-key')

      expect(result).to be(nil)
    end

    it 'returns all headers if no header_name input' do
      result = @tester.response_header(@patient_id, nil)

      expect(result).to be(@tester.reply.request[:headers])
    end
  end

  describe '.request_header' do
    it 'uses header from request_map matching ID' do
      result = @tester.request_header(@patient_id, 'Content-Type')

      expect(result).to eq('Content-Type-value')
    end

    it 'returns nil if no headers in request' do
      @tester.request_map[@patient_id].delete(:headers)

      result = @tester.request_header(@patient_id, 'Content-Type')

      expect(result).to be(nil)
    end

    it 'returns nil if header_name input and no match in request headers' do
      result = @tester.request_header(@patient_id, 'unmatched-header-key')

      expect(result).to be(nil)
    end

    it 'returns all headers if no header_name input' do
      result = @tester.request_header(@patient_id, nil)

      expect(result).to be(@tester.reply.request[:headers])
    end
  end

  describe '.content_type' do
    before do
      @assert.contentType = @tester.request_map[@patient_id][:headers]['Content-Type']
    end

    context 'with sourceId' do
      before { @assert.sourceId = @patient_id }

      it 'pass if expected Content-Type header in the stored sourceId request' do
        expect(@tester).to receive(:pass_message)

        @tester.content_type(@assert)
      end

      it 'fail if no Content-Type header in the stored sourceId request' do
        @tester.request_map[@patient_id][:headers].delete('Content-Type')

        expect { @tester.content_type(@assert) }
          .to raise_exception(Assertion::AssertionException, @tester.fail_message("Content-Type", nil, "equals", @assert.contentType))
      end

      it 'fail if unexpected Content-Type header in the stored sourceId request' do
        @tester.request_map[@patient_id][:headers]['Content-Type'] = 'random'

        expect { @tester.content_type(@assert) }
          .to raise_exception(Assertion::AssertionException, @tester.fail_message("Content-Type", 'random', "equals", @assert.contentType))
      end
    end

    context 'with no sourceId' do
      it 'pass if expected Content-Type header in the last request' do
        expect(@tester).to receive(:pass_message)

        @tester.content_type(@assert)
      end

      it 'fail if no Content-Type header in the last request' do
        @tester.reply.request[:headers].delete('Content-Type')

        expect { @tester.content_type(@assert) }
          .to raise_exception(Assertion::AssertionException, @tester.fail_message("Content-Type", nil, "equals", @assert.contentType))
      end

      it 'fail if unexpected Content-Type header in the last request' do
        @tester.reply.request[:headers]['Content-Type'] = 'random'

        expect { @tester.content_type(@assert) }
          .to raise_exception(Assertion::AssertionException, @tester.fail_message("Content-Type", 'random', "equals", @assert.contentType))
      end
    end
  end

  describe '.expression' do
    before do
      @assert.value = 'Rainbow'
      @assert.expression = 'Patient.address.first().district'
    end

    context 'with sourceId' do
      before { @assert.sourceId = @patient_id }

      it 'pass if expected expression in the stored sourceId fixture' do
        expect(@tester).to receive(:pass_message)

        @tester.expression(@assert)
      end

      it 'fail if unexpected expression in the stored sourceId fixture' do
        @assert.value = 'unexpected'

        expect { @tester.expression(@assert) }
          .to raise_exception(Assertion::AssertionException, @tester.fail_message("Expression", 'Rainbow', "equals", @assert.value))
      end

      it 'raises an AssertionException if no stored sourceId fixture' do
        @assert.sourceId = 'bad_source_id'

        expect { @tester.expression(@assert) }
          .to raise_exception(Assertion::AssertionException, "No resource given by sourceId.")
      end
    end

    context 'with no sourceId' do
      before { @assert.sourceId = nil }

      it 'pass if expected expression in the last response' do
        expect(@tester).to receive(:pass_message)

        @tester.expression(@assert)
      end

      it 'fail if unexpected expression in the last response' do
        @assert.value = 'unexpected'

        expect { @tester.expression(@assert) }
          .to raise_exception(Assertion::AssertionException, @tester.fail_message("Expression", 'Rainbow', "equals", @assert.value))
      end

      it 'returns nil if no last response' do
        @tester.reply.response = nil

        expect { @tester.expression(@assert) }
          .to raise_exception(Assertion::AssertionException, "No resource given by sourceId.")
      end
    end
  end

  describe '.header_field' do
    before do
      @assert.headerField = 'Content-Type'
      @assert.value = @tester.request_map[@patient_id][:headers]['Content-Type']
    end

    context 'with sourceId' do
      before { @assert.sourceId = @patient_id }

      it 'pass if expected header in the stored sourceId response' do
        expect(@tester).to receive(:pass_message)

        @tester.header_field(@assert)
      end

      it 'fail if expected header not in the stored sourceId response' do
        @tester.request_map[@patient_id][:headers].delete('Content-Type')

        expect { @tester.header_field(@assert) }
          .to raise_exception(Assertion::AssertionException, @tester.fail_message("Header Content-Type", nil, "equals", @assert.value))
      end

      it 'fail if unexpected header value in the stored sourceId response' do
        @tester.request_map[@patient_id][:headers]['Content-Type'] = 'random'

        expect { @tester.header_field(@assert) }
          .to raise_exception(Assertion::AssertionException, @tester.fail_message("Header Content-Type", 'random', "equals", @assert.value))
      end
    end

    context 'with no sourceId' do
      it 'pass if expected header in the last response' do
        expect(@tester).to receive(:pass_message)

        @tester.header_field(@assert)
      end

      it 'fail if expected header not in the last response' do
        @tester.reply.request[:headers].delete('Content-Type')

        expect { @tester.header_field(@assert) }
          .to raise_exception(Assertion::AssertionException, @tester.fail_message("Header Content-Type", nil, "equals", @assert.value))
      end

      it 'fail if unexpected Content-Type header in the last request' do
        @tester.reply.request[:headers]['Content-Type'] = 'random'

        expect { @tester.header_field(@assert) }
          .to raise_exception(Assertion::AssertionException, @tester.fail_message("Header Content-Type", 'random', "equals", @assert.value))
      end
    end
  end
end