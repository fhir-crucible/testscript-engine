# frozen_string_literal: true

require_relative '../lib/testscript_runnable'

describe TestScriptRunnable do
  let(:serverId) { 'server_id' }
  let(:targetId) { 'target_id' }
  let(:sourceId) { 'source_id' }
  let(:requestId) { 'request_id' }
  let(:responseId) { 'response_id' }
  let(:locationId) { 'location_id' }
  let(:url) { 'https://example.com' }
  let(:client) { FHIR::Client.new url }
  let(:id_map) { { targetId => serverId } }
  let(:operation) { FHIR::TestScript::Setup::Action::Operation.new }
  let(:client_reply) { FHIR::ClientReply.new(request, response, client) }
  let(:request) do
    {
      method: :get,
      url: url,
      path: "Patient/#{serverId}/$everything"
    }
  end
  let(:response) do
    {
      code: 200,
      headers: { 'location' => "#{url}/Patient/#{locationId}/_history/c07e08c4-2a3a-4293-93ec-6d93688a23f5" },
      body: FHIR::Patient.new(id: serverId).to_json
    }
  end
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

  before do
    runnable.id_map[targetId] = serverId
    runnable.client.reply = client_reply
  end

  context '#storage' do
    context 'with client.reply == nil' do
      before { runnable.client.reply = nil }

      it 'sets @reply to nil' do
        runnable.storage(operation)

        expect(runnable.reply).to be_nil
      end

      it 'sets client.reply to nil' do
        runnable.storage(operation)

        expect(runnable.client.reply).to be_nil
      end

      it 'returns nil' do
        expect(runnable.storage(operation)).to be_nil
      end
    end

    context 'with client.reply' do
      it 'sets @reply to client.reply' do
        runnable.storage(operation)

        expect(runnable.reply).to eq(client_reply)
      end

      it 'sets client.reply to nil' do
        runnable.storage(operation)

        expect(runnable.client.reply).to be_nil
      end

      context 'with op.requestId' do
        before { operation.requestId = requestId }

        it 'stores request' do
          runnable.storage(operation)

          expect(runnable.request_map).to eq({ requestId => client_reply.request })
        end
      end

      context 'with op.responseId' do
        before { operation.responseId = responseId }

        it 'stores response' do
          runnable.storage(operation)

          expect(runnable.response_map).to eq({ responseId => client_reply.response })
        end
      end

      context 'with FHIR resource response' do
        it 'updates reply.resource' do
          runnable.storage(operation)

          expect(runnable.reply.resource.class).to be(FHIR::Patient)
        end
      end

      context 'with non-FHIR resource response' do
        before { runnable.client.reply.response[:body] = nil }

        it 'ignores reply.resource' do
          runnable.storage(operation)

          expect(runnable.reply.resource).to be_nil
        end
      end

      context 'with op.targetId' do
        before { operation.targetId = targetId }

        context 'without :delete' do
          it "doesn't delete @id_map[targetId]" do
            runnable.storage(operation)

            expect(runnable.id_map).to eq(id_map)
          end
        end

        context 'with unsuccessful :delete' do
          before do
            runnable.client.reply.request[:method] = :delete
            runnable.client.reply.response[:code] = 400
          end

          it "doesn't delete @id_map[targetId]" do
            runnable.storage(operation)

            expect(runnable.id_map).to eq(id_map)
          end
        end

        context 'with successful :delete' do
          before do
            runnable.client.reply.request[:method] = :delete
            runnable.client.reply.response[:code] = 204
          end

          it 'deletes @id_map[targetId]' do
            runnable.storage(operation)

            expect(runnable.id_map).to eq({})
          end
        end
      end

      context 'with op.requestId, op.responseId, and op.targetId + :delete' do
        before do
          operation.requestId = requestId
          operation.responseId = responseId
          operation.targetId = targetId
          runnable.client.reply.request[:method] = :delete
          runnable.client.reply.response[:code] = 204
        end

        it 'stores both request and response and deletes @id_map[targetId]' do
          runnable.storage(operation)

          expect(runnable.request_map).to eq({ requestId => client_reply.request })
          expect(runnable.response_map).to eq({ responseId => client_reply.response })
          expect(runnable.id_map).to eq({})
        end
      end

      context 'with reply.resource' do
        context 'with op.responseId' do
          before { operation.responseId = responseId }

          it 'maps responseId => resource.id' do
            runnable.storage(operation)

            expect(runnable.id_map).to eq(id_map.merge!({ responseId => serverId }))
          end
        end

        context 'with op.sourceId' do
          before { operation.sourceId = sourceId }

          it 'maps sourceId => resource.id' do
            runnable.storage(operation)

            expect(runnable.id_map).to eq(id_map.merge!({ sourceId => serverId }))
          end
        end
      end

      context 'without reply.resource and with location header' do
        before { runnable.client.reply.response[:body] = nil }

        context 'with op.responseId' do
          before { operation.responseId = responseId }

          it 'maps responseId => location' do
            runnable.storage(operation)

            expect(runnable.id_map).to eq(id_map.merge!({ responseId => locationId }))
          end
        end

        context 'with op.sourceId' do
          before { operation.sourceId = sourceId }

          it 'maps sourceId => location' do
            runnable.storage(operation)

            expect(runnable.id_map).to eq(id_map.merge!({ sourceId => locationId }))
          end
        end
      end

      context 'without reply.resource nor location header' do
        before do
          runnable.client.reply.response[:body] = nil
          runnable.client.reply.response[:headers] = nil
        end

        it 'ignores id_map and returns nil' do
          result = runnable.storage(operation)

          expect(runnable.id_map).to eq(id_map)
          expect(result).to be_nil
        end
      end

      context 'with op.requestId, op.responseId, and reply.resource' do
        before do
          operation.requestId = requestId
          operation.responseId = responseId
          operation.targetId = targetId
        end

        it 'stores both request and response and deletes @id_map[targetId]' do
          runnable.storage(operation)

          expect(runnable.request_map).to eq({ requestId => client_reply.request })
          expect(runnable.response_map).to eq({ responseId => client_reply.response })
          expect(runnable.id_map).to eq(id_map.merge!({ responseId => serverId }))
        end
      end
    end
  end
end
