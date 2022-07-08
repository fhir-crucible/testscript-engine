require 'TestScriptRunnable'

describe TestScriptRunnable do
  before(:all) do
    @sourceId = 'source_id'
    @serverId = 'server_id'
    @targetId = 'target_id'
    @id_path = "/#{@serverId}"
    @resource = FHIR::Patient.new
    @url = 'https://localhost:8080'
    @patient_url = "#{@url}/Patient"
    @patient_id_url =  "#{@url}/Patient/#{@serverId}"
    @operation = FHIR::TestScript::Setup::Action::Operation.new(encodeRequestUrl: true)
    @response = {
                  code: 200,
                  headers: { 'location' => "#{@url}/Patient/#{@serverId}" },
                  body: @resource.to_json
                }
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
    @runnable.id_map[@targetId] = @serverId
    @runnable.fixtures[@sourceId] = @resource
    @runnable.response_map[@targetId] = @response
  end

  describe '.execute_operation' do
    describe 'given create' do
      let(:create_request) {
        stub_request(:post, @patient_url)
          .with(body: @resource.to_xml)
          .to_return(status: 200, body: FHIR::OperationOutcome.new.to_json)
      }

      before do
        create_request
        @operation.local_method = 'post'
      end

      describe 'with sourceId' do
        before { @operation.sourceId = @sourceId }

        describe 'and url' do
          before { @operation.url = @patient_url }

          it 'sends request and passes' do
            result = @runnable.execute_operation(@operation)

            expect(result).to eq('pass')
            expect(create_request).to have_been_made.once
          end
        end

        it 'sends request and passes' do
          result = @runnable.execute_operation(@operation)

          expect(result).to eq('pass')
          expect(create_request).to have_been_made.once
        end
      end
    end

    context 'given read' do
      let(:read_request) {
        stub_request(:get, @patient_id_url)
          .with(body: nil)
          .to_return(status: 200, body: FHIR::OperationOutcome.new.to_json)
      }

      before do
        read_request
        @operation.local_method = 'get'
      end

      context 'with sourceId' do
        before { @operation.sourceId = @sourceId }

        context 'and url' do
          before { @operation.url = @patient_id_url }

          it 'sends request and passes' do
            result = @runnable.execute_operation(@operation)

            expect(result).to eq('pass')
            expect(read_request).to have_been_made.once
          end
        end

        context 'and params' do
          before do
            @operation.resource = 'Patient'
            @operation.params = @id_path
          end

          it 'sends request and passes' do
            result = @runnable.execute_operation(@operation)

            expect(result).to eq('pass')
            expect(read_request).to have_been_made.once
          end
        end

        context 'and targetId' do
          before { @operation.targetId = @targetId }

          it 'sends request and passes' do
            result = @runnable.execute_operation(@operation)

            expect(result).to eq('pass')
            expect(read_request).to have_been_made.once
          end
        end
      end

      context 'without sourceId' do
        context 'and url' do
          before { @operation.url = @patient_id_url }

          it 'sends request and passes' do
            result = @runnable.execute_operation(@operation)

            expect(result).to eq('pass')
            expect(read_request).to have_been_made.once
          end
        end

        context 'and params' do
          before do
            @operation.resource = 'Patient'
            @operation.params = @id_path
          end

          it 'sends request and passes' do
            result = @runnable.execute_operation(@operation)

            expect(result).to eq('pass')
            expect(read_request).to have_been_made.once
          end
        end

        context 'and targetId' do
          before { @operation.targetId = @targetId }

          it 'sends request and passes' do
            result = @runnable.execute_operation(@operation)

            expect(result).to eq('pass')
            expect(read_request).to have_been_made.once
          end
        end
      end
    end

    context 'given update' do
      let(:put_request) {
        stub_request(:put, @patient_id_url)
          .with(body: @resource.to_xml)
          .to_return(status: 200, body: FHIR::OperationOutcome.new.to_json)
      }

      before do
        put_request
        @operation.local_method = 'put'
      end

      context 'with sourceId' do
        before { @operation.sourceId = @sourceId }

        context 'and url' do
          before { @operation.url = @patient_id_url }

          it 'sends request and passes' do
            result = @runnable.execute_operation(@operation)

            expect(result).to eq('pass')
            expect(put_request).to have_been_made.once
          end
        end

        context 'and params' do
          before do
            @operation.params = @id_path
            @operation.resource = 'Patient'
          end

          it 'sends request and passes' do
            result = @runnable.execute_operation(@operation)

            expect(result).to eq('pass')
            expect(put_request).to have_been_made.once
          end
        end

        context 'and targetId' do
          before { @operation.targetId = @targetId }

          it 'sends request and passes' do
            result = @runnable.execute_operation(@operation)

            expect(result).to eq('pass')
            expect(put_request).to have_been_made.once
          end
        end
      end
    end

    context 'given delete' do
      let(:delete_request) {
        stub_request(:delete, @patient_id_url)
          .with(body: nil)
          .to_return(status: 200, body: FHIR::OperationOutcome.new.to_json)
      }

      before do
        delete_request
        @operation.local_method = 'delete'
      end

      context 'with sourceId' do
        before { @operation.sourceId = @sourceId }

        context 'and url' do
          before { @operation.url = @patient_id_url }

          it 'send request and passes' do
            result = @runnable.execute_operation(@operation)

            expect(result).to eq('pass')
            expect(delete_request).to have_been_made.once
          end
        end

        context 'and params' do
          before do
            @operation.params = @id_path
            @operation.resource = 'Patient'
          end

          it 'send request and passes' do
            result = @runnable.execute_operation(@operation)

            expect(result).to eq('pass')
            expect(delete_request).to have_been_made.once
          end
        end

        context 'and targetId' do
          before { @operation.targetId = @targetId }

          it 'send request and passes' do
            result = @runnable.execute_operation(@operation)

            expect(result).to eq('pass')
            expect(delete_request).to have_been_made.once
          end
        end
      end

      context 'without sourceId' do
        context 'and url' do
          before { @operation.url = @patient_id_url }

          it 'send request and passes' do
            result = @runnable.execute_operation(@operation)

            expect(result).to eq('pass')
            expect(delete_request).to have_been_made.once
          end
        end

        context 'and params' do
          before do
            @operation.params = @id_path
            @operation.resource = 'Patient'
          end

          it 'send request and passes' do
            result = @runnable.execute_operation(@operation)

            expect(result).to eq('pass')
            expect(delete_request).to have_been_made.once
          end
        end

        context 'and targetId' do
          before { @operation.targetId = @targetId }

          it 'send request and passes' do
            result = @runnable.execute_operation(@operation)

            expect(result).to eq('pass')
            expect(delete_request).to have_been_made.once
          end
        end
      end
    end
  end
end