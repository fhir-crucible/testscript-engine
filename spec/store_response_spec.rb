# frozen_string_literal: true

require_relative '../lib/testscript_engine/testscript_runnable'

describe TestScriptRunnable do
  before(:all) do
    url = 'https://example.com'
    client = FHIR::Client.new(url)
    @server_id = 'server_id'
    @target_id = 'target_id'
    @request_id = 'request_id'
    @location_id = 'location_id'
    @source_id = 'source_id'
    @response_id = 'response_id'
    @id_map = { @target_id => @server_id }
    request = { method: :get, url: url, path: "Patient/#{@server_id}/$everything" }
    patient_json = FHIR::Patient.new(id: @server_id).to_json
    response = {
      code: 200,
      headers: { 'location' => "#{url}/Patient/#{@location_id}/_history/c07e08c4-2a3a-4293-93ec-6d93688a23f5" },
      body: patient_json
    }
    @patient = FHIR.from_contents(patient_json)
    @client_reply = FHIR::ClientReply.new(request, response, client)
    @operation = FHIR::TestScript::Setup::Action::Operation.new
    @script = FHIR.from_contents(File.read('spec/examples/basic_testscript.json'))
    options = {"ext_validator" => nil, "ext_fhirpath" => nil}
    @runnable = TestScriptRunnable.new(@script, lambda { |k| {}[k] }, options)
    @runnable.client = client
  end

  before(:each) do
    @runnable.id_map.clear
    @runnable.id_map[@target_id] = @server_id
    @runnable.client.reply = @client_reply.deep_dup
  end

  context '.storage' do
    context 'with client.reply == nil' do
      before { @runnable.client.reply = nil }

      it 'sets @reply to nil' do
        @runnable.storage(@operation)

        expect(@runnable.reply).to be_nil
      end

      it 'sets client.reply to nil' do
        @runnable.storage(@operation)

        expect(@runnable.client.reply).to be_nil
      end

      it 'returns nil' do
        expect(@runnable.storage(@operation)).to be_nil
      end
    end

    context 'with client.reply' do
      it 'sets @reply to client.reply' do
        @runnable.storage(@operation)

        @client_reply.resource = @patient

        expect(@runnable.reply.to_json).to eq(@client_reply.to_json)
      end

      it 'sets client.reply to nil' do
        @runnable.storage(@operation)

        expect(@runnable.client.reply).to be_nil
      end

      context 'with op.requestId' do
        before { @operation.requestId = @request_id }

        it 'stores request' do
          @runnable.storage(@operation)

          expect(@runnable.request_map).to eq({ @request_id => @client_reply.request })
        end
      end

      context 'with op.responseId' do
        before { @operation.responseId = @response_id }

        it 'stores response' do
          @runnable.storage(@operation)

          expect(@runnable.response_map).to eq({ @response_id => @client_reply.response })
        end
      end

      context 'with FHIR resource response' do
        it 'updates reply.resource' do
          @runnable.storage(@operation)

          expect(@runnable.reply.resource.class).to be(FHIR::Patient)
        end
      end

      context 'with non-FHIR resource response' do
        it 'ignores reply.resource' do
          @runnable.client.reply.resource = nil
          @runnable.client.reply.response[:body] = nil

          @runnable.storage(@operation)

          expect(@runnable.reply.resource).to be_nil
        end
      end

      context 'with op.targetId' do
        context 'without :delete' do
          it "doesn't delete @id_map[targetId]" do
            @operation.responseId = nil

            @runnable.storage(@operation)

            expect(@runnable.id_map).to eq(@id_map)
          end
        end

        context 'with unsuccessful :delete' do
          before do
            @runnable.client.reply.request[:method] = :delete
            @runnable.client.reply.response[:code] = 400
          end

          it "doesn't delete @id_map[targetId]" do
            @runnable.storage(@operation)

            expect(@runnable.id_map).to eq(@id_map)
          end
        end

        context 'with successful :delete' do
          before do
            @runnable.client.reply.request[:method] = :delete
            @runnable.client.reply.response[:code] = 204
          end

          it 'deletes @id_map[targetId]' do
            @operation.targetId = @target_id

            @runnable.storage(@operation)

            expect(@runnable.id_map).to eq({})
          end
        end
      end

      context 'with op.requestId, op.responseId, and op.targetId + :delete' do
        before do
          @operation.requestId = @request_id
          @operation.responseId = @response_id
          @operation.targetId = @target_id
          @runnable.client.reply.request[:method] = :delete
          @runnable.client.reply.response[:code] = 204
        end

        it 'stores both request and response and deletes @id_map[targetId]' do
          @runnable.storage(@operation)

          expect(@runnable.request_map).to eq({ @request_id => @client_reply.request })
          expect(@runnable.response_map).to eq({ @response_id => @client_reply.response })
          expect(@runnable.id_map).to eq({})
        end
      end

      context 'with reply.resource' do
        context 'with op.responseId' do
          before { @operation.responseId = @response_id }

          it 'maps @response_id => resource.id' do
            @runnable.storage(@operation)

            expect(@runnable.response_map).to eq({ @response_id => @runnable.reply.response })
            expect(@runnable.request_map).to eq({ @request_id => @runnable.reply.request })
            expect(@runnable.id_map).to eq({})
          end
        end
      end

        # context 'with op.sourceId' do
        #   before { @operation.sourceId = @source_id }

      #     it 'maps sourceId => resource.id' do
      #       @runnable.client.reply.request[:method] = :post

      #       @runnable.storage(@operation)

      #       expect(@runnable.id_map).to eq(@id_map.merge!({ @source_id => @server_id }))
      #     end
      #   end
      # end

      # context 'without reply.resource and with location header' do
      #   before { @runnable.client.reply.response[:body] = nil }

      #   context 'with op.responseId' do
      #     before { @operation.responseId = @response_id }

      #     it 'maps @response_id => location' do
      #       @runnable.storage(@operation)

      #       expect(@runnable.id_map).to eq(@id_map.merge!({ @response_id => locationId }))
      #     end
      #   end

      #   context 'with op.sourceId' do
      #     before { @operation.sourceId = sourceId }

      #     it 'maps sourceId => location' do
      #       @runnable.storage(@operation)

      #       expect(@runnable.id_map).to eq(@id_map.merge!({ sourceId => locationId }))
      #     end
      #   end
      # end

      # context 'without reply.resource nor location header' do
      #   before do
      #     @runnable.client.reply.response[:body] = nil
      #     @runnable.client.reply.response[:headers] = nil
      #   end

      #   it 'ignores id_map and returns nil' do
      #     result = @runnable.storage(@operation)

      #     expect(@runnable.id_map).to eq(@id_map)
      #     expect(result).to be_nil
      #   end
      # end

      # context 'with op.requestId, op.responseId, and reply.resource' do
      #   before do
      #     @operation.requestId = @request_id
      #     @operation.responseId = @response_id
      #     @operation.targetId = @target_id
      #   end

      #   it 'stores both request and response and deletes @id_map[targetId]' do
      #     @runnable.storage(@operation)

      #     expect(@runnable.request_map).to eq({ @requestId => @client_reply.request })
      #     expect(@runnable.response_map).to eq({ @response_id => @client_reply.response })
      #     expect(@runnable.id_map).to eq(@id_map.merge!({ @response_id => @server_id }))
      #   end
      # end
    end
  end
end
