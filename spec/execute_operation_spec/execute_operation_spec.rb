# frozen_string_literal: true

require 'TestScriptRunnable'

describe TestScriptRunnable do
  before(:all) do
    @url = 'https://localhost:8080'
    @patient_id_path = 'Patient/123'
    @request = [:get, @patient_id_path]
    @patient_id_url = "#{@url}/#{@patient_id_path}"
    @operation = FHIR::TestScript::Setup::Action::Operation.new(encodeRequestUrl: true)
    @runnable = TestScriptRunnable.new FHIR::TestScript.new(
      {
        "resourceType": 'TestScript',
        "url": 'http://hl7.org/fhir/TestScript/testscript-example-history',
        "name": 'TestScript-Example-History',
        "status": 'draft',
        "variable": [
          FHIR::TestScript::Variable.new({
            name: 'var_name',
            defaultValue: @serverId
          }).to_hash
        ]
      }
    )
  end

  describe '.execute_operation' do
    it 'fails if given non-operation' do
      result = @runnable.execute_operation(nil)

      expect(result).to eq('fail')
    end

    it 'fails if given invalid operation' do
      result = @runnable.execute_operation(FHIR::TestScript::Setup::Action::Operation.new)

      expect(result).to eq('fail')
    end

    it 'fails if request can not be created' do
      allow(@runnable).to receive(:create_request)
        .with(@operation).and_return(nil)

      result = @runnable.execute_operation(@operation)

      expect(result).to eq('fail')
    end

    it 'fails if sending request raises error' do
      allow(@runnable).to receive(:create_request)
        .with(@operation).and_return(@request)
      allow(@runnable.client).to receive(:send)
        .with(*@request).and_raise(StandardError)

      result = @runnable.execute_operation(@operation)

      expect(result).to eq('fail')
    end

    it 'passes and calls storage if request is sent' do
      stub_request(:get, @patient_id_url)
      allow(@runnable).to receive(:create_request)
        .with(@operation).and_return(@request)
      expect(@runnable).to receive(:storage).with(@operation)

      result = @runnable.execute_operation(@operation)

      expect(result).to eq('pass')
    end
  end
end
