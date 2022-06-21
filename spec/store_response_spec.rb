require 'TestScriptRunnable'

describe TestScriptRunnable do
  # let(:requestId) { 'requestId' }
  # let(:resource) { FHIR::AllergyIntolerance.new }
  # let(:resourceResponse) { { :code => 200, :headers => {}, :body => resource.to_json } }
  # let(:resourceReply) { FHIR::ClientReply.new(nil, resourceResponse, client) }
  # let(:nonResourceResponse) { { :code => 200, :headers => {}, :body => 'body' } }
  # let(:nonResourceReply) { FHIR::ClientReply.new(nil, nonResourceResponse, client) }
  # let(:requestType) { :get }
    # let(:empty_client_reply) { FHIR::ClientReply.new(nil, nil, client) }

  let(:base_url) { 'https://example.com' }
  let(:server_id) { 'abcdefgh12345678' }
  let(:id) { 'some_id' }
  let(:client) { FHIR::Client.new base_url }
  let(:operation) { FHIR::TestScript::Setup::Action::Operation.new }
  let(:runnable) {
    TestScriptRunnable.new FHIR::TestScript.new(
      {
        "resourceType": 'TestScript',
        "url": 'http://hl7.org/fhir/TestScript/testscript-example-history',
        "name": 'TestScript-Example-History',
        "status": 'draft'
      }
    )
  }
  let(:request) {
    { 
      :method => :get, 
      :url => base_url, 
      :path => "Patient/#{server_id}/$everything",
      :headers => {}, 
      :payload => nil
    }
  }
  let(:response) { 
    {
      :code=>200, 
      :headers=>{"date"=>"Tue, 21 Jun 2022 13:41:44 GMT", "content-type"=>"application/fhir+json; fhirVersion=4.0; charset=utf-8", "content-length"=>"3162", "connection"=>"keep-alive", "etag"=>"W/\"c07e08c4-2a3a-4293-93ec-6d93688a23f5\"", "last-modified"=>"Tue, 21 Jun 2022 13:05:49 GMT", "location"=>"#{base_url}/Patient/#{server_id}/_history/c07e08c4-2a3a-4293-93ec-6d93688a23f5", "strict-transport-security"=>"max-age=15724800; includeSubDomains"}, 
      :body=>"{\n  \"id\": \"#{server_id}\",\n  \"active\": true,\n  \"name\": [\n    {\n      \"use\": \"official\",\n      \"family\": \"Chalmers\",\n      \"given\": [\n        \"Peter\",\n        \"James\"\n      ]\n    },\n    {\n      \"use\": \"usual\",\n      \"given\": [\n        \"Jim\"\n      ]\n    },\n    {\n      \"use\": \"maiden\",\n      \"family\": \"Windsor\",\n      \"given\": [\n        \"Peter\",\n        \"James\"\n      ],\n      \"period\": {\n        \"end\": \"2002\"\n      }\n    }\n  ],\n  \"gender\": \"male\",\n  \"birthDate\": \"1974-12-25\",\n  \"deceasedBoolean\": false,\n  \"resourceType\": \"Patient\"\n}" 
    }
  }
  let(:client_reply) { FHIR::ClientReply.new(request, response, client) }

  context '#storage' do
    context 'when client.reply == nil' do
      it 'sets @reply = nil' do
        runnable.storage(operation)

        expect(runnable.reply).to be(nil)
      end 

      it 'sets client.reply = nil' do
        runnable.storage(operation)

        expect(runnable.client.reply).to be(nil)
      end 

      it 'returns nil' do
        expect(runnable.storage(operation)).to be(nil)
      end 
    end 

    context 'when client.reply != nil' do
      before { runnable.client.reply = client_reply }

      it 'sets @reply = client.reply' do
        runnable.storage(operation)

        expect(runnable.reply).to eq(client_reply)
      end 
      
      it 'sets client.reply = nil' do
        runnable.storage(operation)

        expect(runnable.client.reply).to be(nil)
      end 

      context 'and requestId != nil' do
        before { operation.requestId = id }

        it 'updates @request_map' do
          runnable.storage(operation)

          expect(runnable.request_map[id]).to eq(request)
        end 
      end 

      context 'and responseId != nil' do
        before { operation.responseId = id }

        it 'updates @response_map' do
          runnable.storage(operation)

          expect(runnable.response_map[id]).to eq(response)
        end 

        context 'and reply.resource != nil' do
          it 'updates @id_map using reply.resource.id' do
            runnable.storage(operation)

            expect(runnable.id_map[id]).to eq(server_id)
          end
        end
  
        context 'and reply.resource == nil' do
          before { runnable.client.reply.response[:body] = nil }

          it 'updates @id_map using location header' do
            runnable.storage(operation)

            expect(runnable.id_map[id]).to eq(server_id)
          end 
        end 
      end 

      context 'and request type == :delete' do
        before { runnable.client.reply.request[:method] = :delete }

        context 'and status code == `okay`' do
          before { runnable.client.reply.response[:code] = 202 }

          context 'and id extractable from request.path' do

            context 'with id stored' do
              before { runnable.id_map[id] = server_id }

              it 'updates @id_map' do
                runnable.storage(operation)
  
                expect(runnable.id_map).to eq({})
              end 
            end 


            context 'without id stored' do
              it 'ignores @id_map' do

              end 
            end 
          end

          context 'and id not extracted from path' do
            context 'with reponseId' do

            end 

            it 'prints a warning' do

            end 

            it 'ignores @id_map' do

            end 
          end
        end

        context 'and status code != `okay`' do
          it 'ignores @id_map' do

          end 
        end
      end

      context 'and sourceId != nil' do 
        context 'and reply.resource != nil' do
          it 'updates @id_map using reply.resource.id' do

          end
        end
  
        context 'and reply.resource == nil' do
          it 'updates @id_mdap using location header' do

          end 
        end 
      end 
    end 
  end 
end 