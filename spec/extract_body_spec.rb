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
  let(:runnable) do
    TestScriptRunnable.new FHIR::TestScript.new(
      {
        "resourceType": 'TestScript',
        "url": 'http://hl7.org/fhir/TestScript/testscript-example-history',
        "name": 'TestScript-Example-History',
        "status": 'draft'
      }
    )
  end

  describe '#extract_body' do
    context 'given non-sender request' do
      let(:request_type) { :get }

      it 'returns nil' do
        expect(runnable.extract_body(operation, request_type)).to eq(nil)
      end
    end

    context 'given sender request' do
      context 'with sourceId' do
        before { operation.sourceId = sourceId }

        context 'denoting Resource A' do
          before { runnable.fixtures[sourceId] = resource }

          it 'returns Resource A' do
            expect(runnable.extract_body(operation, request_type)).to eq(resource)
          end
        end

        context 'not denoting some Resource A' do
          it 'returns nil' do
            expect(runnable.extract_body(operation, request_type)).to eq(nil)
          end
        end
      end

      context 'with targetId' do
        before { operation.targetId = targetId }

        context 'denoting Resource A' do
          before do
            clientReply.resource = resource
            runnable.response_map[targetId] = clientReply
          end

          it 'returns Resource A' do
            expect(runnable.extract_body(operation, request_type)).to eq(resource)
          end
        end

        context 'not denoting some Resource A' do
          it 'returns nil' do
            expect(runnable.extract_body(operation, request_type)).to eq(nil)
          end
        end
      end

      context 'with neither sourceId nor targetId' do
        it 'returns nil' do
          expect(runnable.extract_body(operation, request_type)).to eq(nil)
        end
      end
    end
  end
end
