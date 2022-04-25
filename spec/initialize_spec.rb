# frozen_string_literal: true
require 'TestScriptRunnable'

describe TestScriptRunnable do
  let(:tScript) { FHIR::TestScript.new }
  let(:url) { 'https://some_url' }
  let(:client) { FHIR::Client.new(url) }
  let(:default_url) { 'https://localhost:4567' }

  describe '.initialize' do
    context 'with an invalid TestScript given' do
      it 'logs and raises an error' do
        expect(FHIR.logger).to receive(:error).exactly(4).times.with '[.initialize] Received invalid TestScript resource. Unable to create TestScriptRunnable.'

        expect { TestScriptRunnable.new(nil) }.to raise_error(TypeError)
        expect { TestScriptRunnable.new(0) }.to raise_error(TypeError)
        expect { TestScriptRunnable.new('notTestScript') }.to raise_error(TypeError)
        expect { TestScriptRunnable.new(FHIR::TestReport.new) }.to raise_error(TypeError)
      end 
    end 

    context 'with valid TestScript given' do
      it 'initializes expected attributes' do
        runnable = TestScriptRunnable.new(tScript)

        expect(runnable.tScript).to eq(tScript)
        expect(runnable.report).to be_a(FHIR::TestReport)
        expect(runnable.fixtures).to be_a(Hash)
        expect(runnable.id_map).to be_a(Hash)
        expect(runnable.autocreate).to be_a(Array)
        expect(runnable.autodelete).to be_a(Array)
        expect(runnable.client.instance_variable_get(:@base_service_url)).to eq(default_url)
      end 

      it 'calls load_fixtures' do
        expect_any_instance_of(TestScriptRunnable).to receive(:load_fixture)
        TestScriptRunnable.new(tScript)
      end 

      it 'returns a runnable' do
        runnable = TestScriptRunnable.new(tScript)
        expect(runnable).to be_a(TestScriptRunnable)
      end 
    end
  end 

  context '.execution' do
    context 'with an invalid TestScript given' do
      it 'logs and raises an error' do
        expect(FHIR.logger).to receive(:error).exactly(4).times.with '[.initialize] Received invalid TestScript resource. Unable to create TestScriptRunnable.'

        expect { TestScriptRunnable.execute(nil) }.to raise_error(TypeError)
        expect { TestScriptRunnable.execute(0) }.to raise_error(TypeError)
        expect { TestScriptRunnable.execute('notTestScript') }.to raise_error(TypeError)
        expect { TestScriptRunnable.execute(FHIR::TestReport.new) }.to raise_error(TypeError)
      end 
    end 

    context 'without a client given' do
      it 'sets the client attribute to the default localhost value' do
        report = TestScriptRunnable.execute(tScript)

        expect(report.participant[1].type == 'Client')
        expect(report.participant[1].type == default_url)
      end 
    end 
    
    context 'with a client given' do
      it 'sets the client attribute' do
        report = TestScriptRunnable.execute(tScript)

        expect(report.participant[1].type == 'Client')
        expect(report.participant[1].type == url)
      end 

      it 'returns a report' do
        runnable = TestScriptRunnable.execute(tScript)
        expect(runnable).to be_a(FHIR::TestReport)
      end 
    end 
  end 
end 