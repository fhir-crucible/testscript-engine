# frozen_string_literal: true

require_relative '../lib/testscript_engine/validation'

class ValidationTestClass
  include Validation
end

describe Validation do
  before(:all) do
    @resource = FHIR::Patient.new
    @url = 'https://example.com'
    @validation_tester = ValidationTestClass.new
    response = { code: 200, body: @resource.to_json }
    request = { method: :post, url: @url, path: 'Patient/$validate' }
    @reply = FHIR::ClientReply.new(request, response, FHIR::Client.new(@url))
    @profile = 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient'
  end

  describe '.valid_resource?' do
    context 'if $validate supported by endpoint' do
      before { @validation_tester.instance_variable_set(:@validator, FHIR::Client.new(@url)) }

      it 'does not call validate_using_route if $validate supported' do
        stub_request(:post, "#{@url}/Patient/$validate")
          .with(body: "{\n  \"parameter\": [\n    {\n      \"name\": \"resource\",\n      \"resource\": {\n        \"resourceType\": \"Patient\"\n      }\n    }\n  ],\n  \"resourceType\": \"Parameters\"\n}") # rubocop:disable Layout/LineLength

        @validation_tester.valid_resource?(@resource)

        expect(@validation_tester).not_to receive(:validate_using_route)
      end
    end

    context 'with $validate not supported by endpoint' do
      it 'calls validate_using_route' do
        expect(@validation_tester).to receive(:validate_using_route)

        stub_request(:post, "#{@url}/Patient/$validate")
          .with(body: "{\n  \"parameter\": [\n    {\n      \"name\": \"resource\",\n      \"resource\": {\n        \"resourceType\": \"Patient\"\n      }\n    }\n  ],\n  \"resourceType\": \"Parameters\"\n}") # rubocop:disable Layout/LineLength
          .to_return(status: 404)

        @validation_tester.valid_resource?(@resource)
      end
    end
  end

  describe '.validate_using_operation' do
    before { @validation_tester.instance_variable_set(:@validator, FHIR::Client.new(@url)) }

    context 'with endpoint that supports $validate_using_operation' do
      it 'creates request including $validate_using_operation' do
        stubbed_request = stub_request(:post, "#{@url}/Patient/$validate")
                          .with(body: "{\n  \"parameter\": [\n    {\n      \"name\": \"resource\",\n      \"resource\": {\n        \"resourceType\": \"Patient\"\n      }\n    }\n  ],\n  \"resourceType\": \"Parameters\"\n}") # rubocop:disable Layout/LineLength

        @validation_tester.validate_using_operation(@resource)

        expect(stubbed_request).to have_been_made.once
      end

      it 'includes profile in $validate_using_operation body' do
        stubbed_request = stub_request(:post, "#{@url}/Patient/$validate")
                          .with(body: "{\n  \"parameter\": [\n    {\n      \"name\": \"resource\",\n      \"resource\": {\n        \"resourceType\": \"Patient\"\n      }\n    },\n    {\n      \"name\": \"profile\",\n      \"valueUri\": \"http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient\"\n    }\n  ],\n  \"resourceType\": \"Parameters\"\n}") # rubocop:disable Layout/LineLength

        @validation_tester.validate_using_operation(@resource, @profile)

        expect(stubbed_request).to have_been_made.once
      end

      it 'includes multiple profiles in $validate_using_operation path' do
        stubbed_request = stub_request(:post, "#{@url}/Patient/$validate")
                          .with(body: "{\n  \"parameter\": [\n    {\n      \"name\": \"resource\",\n      \"resource\": {\n        \"resourceType\": \"Patient\"\n      }\n    },\n    {\n      \"name\": \"profile\",\n      \"valueUri\": [\n        \"http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient\",\n        \"http://hl7.org/fhir/us/core/StructureDefinition/us-core-patient\"\n      ]\n    }\n  ],\n  \"resourceType\": \"Parameters\"\n}") # rubocop:disable Layout/LineLength

        @validation_tester.validate_using_operation(@resource, [@profile, @profile])

        expect(stubbed_request).to have_been_made.once
      end
    end
  end

  describe './validate_using_route' do
    it 'creates request to `/validate` endpoint' do
      stubbed_request = stub_request(:post, "#{@url}/validate")
                        .with(body: @resource.to_json)

      @validation_tester.validate_using_route(@resource)

      expect(stubbed_request).to have_been_made.once
    end

    it 'includes profile in request to `/validate` endpoint' do
      stubbed_request = stub_request(:post, "#{@url}/validate?profile=#{@profile}")
                        .with(body: @resource.to_json)

      @validation_tester.validate_using_route(@resource, [@profile])

      expect(stubbed_request).to have_been_made.once
    end

    it 'includes multiple profiles in request to `/validate` endpoint' do
      stubbed_request = stub_request(:post, "#{@url}/validate?profile=#{@profile},#{@profile}")
                        .with(body: @resource.to_json)

      @validation_tester.validate_using_route(@resource, [@profile, @profile])

      expect(stubbed_request).to have_been_made.once
    end
  end

  describe '.validation_errors?' do
    before do
      @issue = FHIR::OperationOutcome::Issue.new(type: 'error')
      @pass_operation_outcome = FHIR::OperationOutcome.new
      @fail_operation_outcome = FHIR::OperationOutcome.new(issue: @issue)
    end

    it 'returns false if no errors or warnings in outcome of validation' do
      allow(@validation_tester).to receive(:validation_response).and_return(@pass_operation_outcome)

      result = @validation_tester.validation_errors?

      expect(result).to be false
    end

    it 'returns true if errors or warnings in outcome of validation' do
      allow(@validation_tester).to receive(:validation_response).and_return(@fail_operation_outcome)

      result = @validation_tester.validation_errors?

      expect(result).to be true
    end
  end

  describe '.validation_response' do
    it 'returns an error OperationOutcome if response not JSON' do
      @reply.response[:body] = " _ / ) {this isn't json"
      @validation_tester.validator.reply = @reply.deep_dup

      result = @validation_tester.validation_response

      expect(result).to eq(FHIR::OperationOutcome.new(issue:
        FHIR::OperationOutcome::Issue.new(
          severity: 'error',
          diagnostics: "Unable to process response from validation endpoint: #{@url}"
        )))
    end

    it 'returns the JSON response as an OperationOutcome' do
      @reply.response[:body] = FHIR::OperationOutcome.new.to_json
      @validation_tester.validator.reply = @reply.deep_dup

      result = @validation_tester.validation_response

      expect(result).to eq(FHIR::OperationOutcome.new)
    end
  end
end
