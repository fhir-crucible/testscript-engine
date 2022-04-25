# frozen_string_literal: true

require 'TestScriptRunnable'

describe TestScriptRunnable do
  let(:tScript) { FHIR::TestScript.new }
  let(:runnable) { TestScriptRunnable.new(tScript) }
  let(:endpoint) { 'https://endpoint.com' }
  let(:empty_operation) { FHIR::TestScript::Setup::Action::Operation.new }
  let(:resource_type) { 'Patient' }
  let(:id) { '1' }
  let(:complete_url) { "#{endpoint}/#{resource_type}/#{id}" }
  let(:incomplete_url) { "#{endpoint}/${resource_type}/${id}" }
  let(:default_description) { "If we're checking the message, this operation should pass." }
  let(:format) { FHIR::Formats::ResourceFormat::RESOURCE_JSON }
  let(:system) { 'http://terminology.hl7.org/CodeSystem/testscript-operation-codes' }
  let(:bad_uri_message) { "bad URI(is not URI?): \"#{incomplete_url}\"" }
  let(:targetId) { 'targetId' }
  let(:sourceId) { 'sourceId' }
  let(:payload) { "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<Patient xmlns=\"http://hl7.org/fhir\"/>\n" }
  let(:request_header_input) { { field: 'connection', value: 'keep-alive' } }
  let(:request_header) { [FHIR::TestScript::Setup::Action::Operation::RequestHeader.new(request_header_input)] }
  let(:request_header_hash) do
    hash = {}
    request_header.map { |h| hash[h.field] = h.value }
    hash
  end
  let(:variable) do
    [FHIR::TestScript::Variable.new({
                                      'name' => 'resource_type', 'defaultValue' => resource_type
                                    }),
     FHIR::TestScript::Variable.new({
                                      'name' => 'id', 'defaultValue' => id
                                    })]
  end

  before do
    runnable.client = FHIR::Client.new(endpoint)
    runnable.tScript.variable = variable
    runnable.fixtures[sourceId] = FHIR::Patient.new
  end

  describe '#execute_operation' do
    context 'with client undefined' do
      before { runnable.client = nil }

      it 'returns an fail report' do
        result = runnable.execute_operation(empty_operation)

        expect(result).to eq(runnable.fail_report('noClient'))
      end
    end

    context 'given non-Operation input' do
      context 'of type nil' do
        it 'returns an fail report' do
          result = runnable.execute_operation(nil)

          expect(result).to eq(runnable.fail_report('invalidOperation'))
        end
      end

      context 'of type integer' do
        it 'returns an fail report' do
          result = runnable.execute_operation(404)

          expect(result).to eq(runnable.fail_report('invalidOperation'))
        end
      end

      context 'of type assertion' do
        it 'returns an fail report' do
          result = runnable.execute_operation(FHIR::TestScript::Setup::Action::Assert.new)

          expect(result).to eq(runnable.fail_report('invalidOperation'))
        end
      end
    end

    context 'given Operation without type.code or method' do
      it 'returns an fail report' do
        result = runnable.execute_operation(empty_operation)

        expect(result).to eq(runnable.fail_report('noRequestType'))
      end
    end

    context 'read operation' do
      let(:read_code) do
        FHIR::Coding.new({
                           'code' => 'read',
                           'system' => system
                         })
      end
      let(:read_config) do
        {
          'description' => default_description,
          'type' => read_code
        }
      end
      let(:read_operation) { FHIR::TestScript::Setup::Action::Operation.new(read_config) }

      context 'using url' do
        before { read_operation.url = complete_url }

        context 'that contains variables' do
          before { read_operation.url = incomplete_url }

          context 'that do not resolve to a complete url' do
            before { runnable.tScript.variable = [] }

            it 'fails to make a request to the incomplete url' do
              stub_request(:get, incomplete_url)

              result = runnable.execute_operation(read_operation)
              expect(result).to eq(runnable.error_report(bad_uri_message))
            end
          end

          context 'that do resolve to a complete url' do
            it 'makes a request to the complete url' do
              stub_request(:get, complete_url)
                .to_return(status: 200)

              result = runnable.execute_operation(read_operation)
              expect(result).to eq(runnable.pass_report(default_description))
            end

            context 'with specified headers' do
              before { read_operation.requestHeader = request_header }

              it 'makes a request with specified additional headers' do
                stub_request(:get, complete_url)
                  .with(headers: request_header_hash)
                  .to_return(status: 200)

                result = runnable.execute_operation(read_operation)
                expect(result).to eq(runnable.pass_report(default_description))
              end
            end
          end
        end

        context 'with no variables' do
          it 'makes a request to operation.url' do
            stub_request(:get, complete_url)
              .to_return(status: 200)

            result = runnable.execute_operation(read_operation)
            expect(result).to eq(runnable.pass_report(default_description))
          end

          context 'with specified headers' do
            before { read_operation.requestHeader = request_header }

            it 'makes a request with specified additional headers' do
              stub_request(:get, complete_url)
                .with(headers: request_header_hash)
                .to_return(status: 200)

              result = runnable.execute_operation(read_operation)
              expect(result).to eq(runnable.pass_report(default_description))
            end
          end
        end
      end

      context 'using params' do
        before do
          read_operation.params = id
          read_operation.resource = resource_type
        end

        context 'without defined resource' do
          before { read_operation.resource = nil }

          it 'returns a fail report' do
            result = runnable.execute_operation(read_operation)
            expect(result).to eq(runnable.fail_report('noResource'))
          end
        end

        context 'with defined resource' do
          context 'with variables' do
            before do
              read_operation.resource = '${resource_type}'
              read_operation.params = '/${id}'
            end

            context 'that do not resolve to a complete url' do
              before { runnable.tScript.variable = [] }

              it 'makes a request to the incomplete url' do
                stub_request(:get, incomplete_url)
                  .to_return(status: 400)

                result = runnable.execute_operation(read_operation)
                expect(result).to eq(runnable.pass_report(default_description))
              end

              context 'with specified headers' do
                before { read_operation.requestHeader = request_header }

                it 'includes those headers in the request' do
                  stub_request(:get, incomplete_url)
                    .with(headers: request_header_hash)
                    .to_return(status: 400)

                  result = runnable.execute_operation(read_operation)
                  expect(result).to eq(runnable.pass_report(default_description))
                end
              end
            end

            context 'that do resolve to a complete url' do
              it 'makes a request to the complete url' do
                stub_request(:get, complete_url)
                  .to_return(status: 200)

                result = runnable.execute_operation(read_operation)
                expect(result).to eq(runnable.pass_report(default_description))
              end

              context 'with specified headers' do
                before { read_operation.requestHeader = request_header }

                it 'includes those headers in the request' do
                  stub_request(:get, complete_url)
                    .with(headers: request_header_hash)
                    .to_return(status: 200)

                  result = runnable.execute_operation(read_operation)
                  expect(result).to eq(runnable.pass_report(default_description))
                end
              end
            end
          end

          context 'without variables' do
            it 'makes a request to the url constructed via resource and params' do
              stub_request(:get, complete_url)
                .to_return(status: 200)

              result = runnable.execute_operation(read_operation)
              expect(result).to eq(runnable.pass_report(default_description))
            end

            context 'with specified headers' do
              before { read_operation.requestHeader = request_header }

              it 'makes a request with specified additional headers' do
                stub_request(:get, complete_url)
                  .with(headers: request_header_hash)
                  .to_return(status: 200)

                result = runnable.execute_operation(read_operation)
                expect(result).to eq(runnable.pass_report(default_description))
              end
            end
          end
        end
      end

      context 'using targetId' do
        before do
          read_operation.targetId = targetId
          runnable.fixtures[targetId] = "FHIR::#{resource_type}".constantize.new
          runnable.id_map[targetId] = id
        end

        context 'with no corresponding fixture' do
          before { runnable.fixtures[targetId] = nil }

          it 'returns a fail report' do
            result = runnable.execute_operation(read_operation)
            expect(result).to eq(runnable.fail_report('noTargetIdFixture'))
          end
        end

        context 'with no server id for corresponding fixture' do
          before { runnable.id_map[targetId] = nil }

          it 'returns a fail report' do
            result = runnable.execute_operation(read_operation)
            expect(result).to eq(runnable.fail_report('noId'))
          end
        end

        it 'makes a request to the url constructed from the corresponding fixture and its server id' do
          stub_request(:get, "#{endpoint}/#{resource_type}/#{id}")
            .to_return(status: 200)

          result = runnable.execute_operation(read_operation)
          expect(result).to eq(runnable.pass_report(default_description))
        end

        context 'with specified headers' do
          before { read_operation.requestHeader = request_header }

          it 'makes a request with specified additional headers' do
            stub_request(:get, complete_url)
              .with(headers: request_header_hash)
              .to_return(status: 200)

            result = runnable.execute_operation(read_operation)
            expect(result).to eq(runnable.pass_report(default_description))
          end
        end
      end
    end

    context 'create operation' do
      let(:create_code) do
        FHIR::Coding.new({
                           'code' => 'create',
                           'system' => system
                         })
      end
      let(:create_config) do
        {
          'description' => default_description,
          'type' => create_code,
          'sourceId' => sourceId
        }
      end
      let(:create_operation) { FHIR::TestScript::Setup::Action::Operation.new(create_config) }

      context 'with no sourceId specified' do
        before { create_operation.sourceId = nil }

        it 'returns a fail report' do
          result = runnable.execute_operation(create_operation)
          expect(result).to eq(runnable.fail_report('noSourceId'))
        end
      end

      context 'with no fixture corresponding to sourceId' do
        before { runnable.fixtures = {} }

        it 'retuns a fail report' do
          result = runnable.execute_operation(create_operation)
          expect(result).to eq(runnable.fail_report('noSourceFixture'))
        end
      end

      context 'using url' do
        before { create_operation.url = complete_url }

        context 'that contains variables' do
          before { create_operation.url = incomplete_url }

          context 'that do not resolve to a complete url' do
            before { runnable.tScript.variable = [] }

            it 'fails to make a request to the incomplete url' do
              result = runnable.execute_operation(create_operation)
              expect(result).to eq(runnable.error_report(bad_uri_message))
            end
          end

          context 'that do resolve to a complete url' do
            it 'makes a request to the complete url with fixture payload' do
              stub_request(:post, complete_url)
                .with(body: payload)
                .to_return(status: 200)

              result = runnable.execute_operation(create_operation)
              expect(result).to eq(runnable.pass_report(default_description))
            end

            context 'with specified headers' do
              before { create_operation.requestHeader = request_header }

              it 'makes a request with specified additional headers and body' do
                stub_request(:post, complete_url)
                  .with(headers: request_header_hash, body: payload)
                  .to_return(status: 200)

                result = runnable.execute_operation(create_operation)
                expect(result).to eq(runnable.pass_report(default_description))
              end
            end
          end
        end

        context 'with no variables' do
          it 'makes a request to the url' do
            stub_request(:post, complete_url)
              .with(body: payload)
              .to_return(status: 200)

            result = runnable.execute_operation(create_operation)
            expect(result).to eq(runnable.pass_report(default_description))
          end

          context 'with specified headers' do
            before { create_operation.requestHeader = request_header }

            it 'makes a request with specified additional headers and body' do
              stub_request(:post, complete_url)
                .with(headers: request_header_hash, body: payload)
                .to_return(status: 200)

              result = runnable.execute_operation(create_operation)
              expect(result).to eq(runnable.pass_report(default_description))
            end
          end
        end
      end

      context 'using params' do
        before do
          create_operation.params = id
          create_operation.resource = resource_type
        end

        context 'without defined resource' do
          before { create_operation.resource = nil }

          it 'returns a fail report' do
            result = runnable.execute_operation(create_operation)
            expect(result).to eq(runnable.fail_report('noResource'))
          end
        end

        context 'with defined resource' do
          context 'with variables' do
            before do
              create_operation.resource = '${resource_type}'
              create_operation.params = '/${id}'
            end

            context 'that do not resolve to a complete url' do
              before { runnable.tScript.variable = [] }

              it 'makes a request, with body, to the incomplete url' do
                stub_request(:post, incomplete_url)
                  .to_return(status: 400, body: payload)

                result = runnable.execute_operation(create_operation)
                expect(result).to eq(runnable.pass_report(default_description))
              end

              context 'with specified headers' do
                before { create_operation.requestHeader = request_header }

                it 'includes those headers, and body, in the request' do
                  stub_request(:post, incomplete_url)
                    .with(headers: request_header_hash, body: payload)
                    .to_return(status: 400)

                  result = runnable.execute_operation(create_operation)
                  expect(result).to eq(runnable.pass_report(default_description))
                end
              end
            end

            context 'that do resolve to a complete url' do
              it 'makes a request to the complete url and body' do
                stub_request(:post, complete_url)
                  .to_return(status: 200, body: payload)

                result = runnable.execute_operation(create_operation)
                expect(result).to eq(runnable.pass_report(default_description))
              end

              context 'with specified headers' do
                before { create_operation.requestHeader = request_header }

                it 'includes those headers and body in the request' do
                  stub_request(:post, complete_url)
                    .with(headers: request_header_hash, body: payload)
                    .to_return(status: 200)

                  result = runnable.execute_operation(create_operation)
                  expect(result).to eq(runnable.pass_report(default_description))
                end
              end
            end
          end

          context 'without variables' do
            it 'makes a request to the url, with body, constructed via resource and params' do
              stub_request(:post, complete_url)
                .with(body: payload)
                .to_return(status: 200)

              result = runnable.execute_operation(create_operation)
              expect(result).to eq(runnable.pass_report(default_description))
            end

            context 'with specified headers' do
              before { create_operation.requestHeader = request_header }

              it 'makes a request with specified additional headers and body' do
                stub_request(:post, complete_url)
                  .with(headers: request_header_hash, body: payload)
                  .to_return(status: 200)

                result = runnable.execute_operation(create_operation)
                expect(result).to eq(runnable.pass_report(default_description))
              end
            end
          end
        end
      end

      context 'using targetId' do
        before do
          create_operation.targetId = targetId
          runnable.fixtures[targetId] = "FHIR::#{resource_type}".constantize.new
          runnable.id_map[targetId] = id
        end

        context 'with no corresponding fixture' do
          before { runnable.fixtures[targetId] = nil }

          it 'returns a fail report' do
            result = runnable.execute_operation(create_operation)
            expect(result).to eq(runnable.fail_report('noTargetIdFixture'))
          end
        end

        context 'with no server id for corresponding fixture' do
          before { runnable.id_map[targetId] = nil }

          it 'returns a fail report' do
            result = runnable.execute_operation(create_operation)
            expect(result).to eq(runnable.fail_report('noId'))
          end
        end

        it 'makes a request to the url constructed from the corresponding fixture and its server id' do
          stub_request(:post, "#{endpoint}/#{resource_type}/#{id}")
            .to_return(status: 200)

          result = runnable.execute_operation(create_operation)
          expect(result).to eq(runnable.pass_report(default_description))
        end

        context 'with specified headers' do
          before { create_operation.requestHeader = request_header }

          it 'makes a request with specified additional headers' do
            stub_request(:post, complete_url)
              .with(headers: request_header_hash)
              .to_return(status: 200)

            result = runnable.execute_operation(create_operation)
            expect(result).to eq(runnable.pass_report(default_description))
          end
        end
      end
    end

    context 'update operation' do
      let(:update_code) do
        FHIR::Coding.new({
                           'code' => 'update',
                           'system' => system
                         })
      end
      let(:update_config) do
        {
          'description' => default_description,
          'type' => update_code,
          'sourceId' => sourceId
        }
      end
      let(:update_operation) { FHIR::TestScript::Setup::Action::Operation.new(update_config) }

      context 'with no sourceId specified' do
        before { update_operation.sourceId = nil }

        it 'returns a fail report' do
          result = runnable.execute_operation(update_operation)
          expect(result).to eq(runnable.fail_report('noSourceId'))
        end
      end

      context 'with no fixture corresponding to sourceId' do
        before { runnable.fixtures = {} }

        it 'retuns a fail report' do
          result = runnable.execute_operation(update_operation)
          expect(result).to eq(runnable.fail_report('noSourceFixture'))
        end
      end

      context 'using url' do
        before { update_operation.url = complete_url }

        context 'that contains variables' do
          before { update_operation.url = incomplete_url }

          context 'that do not resolve to a complete url' do
            before { runnable.tScript.variable = [] }

            it 'fails to make a request to the incomplete url' do
              result = runnable.execute_operation(update_operation)
              expect(result).to eq(runnable.error_report(bad_uri_message))
            end
          end

          context 'that do resolve to a complete url' do
            it 'makes a request to the complete url with fixture payload' do
              stub_request(:put, complete_url)
                .with(body: payload)
                .to_return(status: 200)

              result = runnable.execute_operation(update_operation)
              expect(result).to eq(runnable.pass_report(default_description))
            end

            context 'with specified headers' do
              before { update_operation.requestHeader = request_header }

              it 'makes a request with specified additional headers and body' do
                stub_request(:put, complete_url)
                  .with(headers: request_header_hash, body: payload)
                  .to_return(status: 200)

                result = runnable.execute_operation(update_operation)
                expect(result).to eq(runnable.pass_report(default_description))
              end
            end
          end
        end

        context 'with no variables' do
          it 'makes a request to the url' do
            stub_request(:put, complete_url)
              .with(body: payload)
              .to_return(status: 200)

            result = runnable.execute_operation(update_operation)
            expect(result).to eq(runnable.pass_report(default_description))
          end

          context 'with specified headers' do
            before { update_operation.requestHeader = request_header }

            it 'makes a request with specified additional headers and body' do
              stub_request(:put, complete_url)
                .with(headers: request_header_hash, body: payload)
                .to_return(status: 200)

              result = runnable.execute_operation(update_operation)
              expect(result).to eq(runnable.pass_report(default_description))
            end
          end
        end
      end

      context 'using params' do
        before do
          update_operation.params = id
          update_operation.resource = resource_type
        end

        context 'without defined resource' do
          before { update_operation.resource = nil }

          it 'returns a fail report' do
            result = runnable.execute_operation(update_operation)
            expect(result).to eq(runnable.fail_report('noResource'))
          end
        end

        context 'with defined resource' do
          context 'with variables' do
            before do
              update_operation.resource = '${resource_type}'
              update_operation.params = '/${id}'
            end

            context 'that do not resolve to a complete url' do
              before { runnable.tScript.variable = [] }

              it 'makes a request, with body, to the incomplete url' do
                stub_request(:put, incomplete_url)
                  .to_return(status: 400, body: payload)

                result = runnable.execute_operation(update_operation)
                expect(result).to eq(runnable.pass_report(default_description))
              end

              context 'with specified headers' do
                before { update_operation.requestHeader = request_header }

                it 'includes those headers, and body, in the request' do
                  stub_request(:put, incomplete_url)
                    .with(headers: request_header_hash, body: payload)
                    .to_return(status: 400)

                  result = runnable.execute_operation(update_operation)
                  expect(result).to eq(runnable.pass_report(default_description))
                end
              end
            end

            context 'that do resolve to a complete url' do
              it 'makes a request to the complete url and body' do
                stub_request(:put, complete_url)
                  .to_return(status: 200, body: payload)

                result = runnable.execute_operation(update_operation)
                expect(result).to eq(runnable.pass_report(default_description))
              end

              context 'with specified headers' do
                before { update_operation.requestHeader = request_header }

                it 'includes those headers and body in the request' do
                  stub_request(:put, complete_url)
                    .with(headers: request_header_hash, body: payload)
                    .to_return(status: 200)

                  result = runnable.execute_operation(update_operation)
                  expect(result).to eq(runnable.pass_report(default_description))
                end
              end
            end
          end

          context 'without variables' do
            it 'makes a request to the url, with body, constructed via resource and params' do
              stub_request(:put, complete_url)
                .with(body: payload)
                .to_return(status: 200)

              result = runnable.execute_operation(update_operation)
              expect(result).to eq(runnable.pass_report(default_description))
            end

            context 'with specified headers' do
              before { update_operation.requestHeader = request_header }

              it 'makes a request with specified additional headers and body' do
                stub_request(:put, complete_url)
                  .with(headers: request_header_hash, body: payload)
                  .to_return(status: 200)

                result = runnable.execute_operation(update_operation)
                expect(result).to eq(runnable.pass_report(default_description))
              end
            end
          end
        end
      end

      context 'using targetId' do
        before do
          update_operation.targetId = targetId
          runnable.fixtures[targetId] = "FHIR::#{resource_type}".constantize.new
          runnable.id_map[targetId] = id
        end

        context 'with no corresponding fixture' do
          before { runnable.fixtures[targetId] = nil }

          it 'returns a fail report' do
            result = runnable.execute_operation(update_operation)
            expect(result).to eq(runnable.fail_report('noTargetIdFixture'))
          end
        end

        context 'with no server id for corresponding fixture' do
          before { runnable.id_map[targetId] = nil }

          it 'returns a fail report' do
            result = runnable.execute_operation(update_operation)
            expect(result).to eq(runnable.fail_report('noId'))
          end
        end

        it 'makes a request to the url constructed from the corresponding fixture and its server id' do
          stub_request(:put, "#{endpoint}/#{resource_type}/#{id}")
            .to_return(status: 200)

          result = runnable.execute_operation(update_operation)
          expect(result).to eq(runnable.pass_report(default_description))
        end

        context 'with specified headers' do
          before { update_operation.requestHeader = request_header }

          it 'makes a request with specified additional headers' do
            stub_request(:put, complete_url)
              .with(headers: request_header_hash)
              .to_return(status: 200)

            result = runnable.execute_operation(update_operation)
            expect(result).to eq(runnable.pass_report(default_description))
          end
        end
      end
    end

    context 'delete operation' do
      let(:delete_code) do
        FHIR::Coding.new({
                           'code' => 'delete',
                           'system' => system
                         })
      end
      let(:delete_config) do
        {
          'description' => default_description,
          'type' => delete_code
        }
      end
      let(:delete_operation) { FHIR::TestScript::Setup::Action::Operation.new(delete_config) }

      context 'using url' do
        before { delete_operation.url = complete_url }

        context 'that contains variables' do
          before { delete_operation.url = incomplete_url }

          context 'that do not resolve to a complete url' do
            before { runnable.tScript.variable = [] }

            it 'fails to make a request to the incomplete url' do
              stub_request(:delete, incomplete_url)

              result = runnable.execute_operation(delete_operation)
              expect(result).to eq(runnable.error_report(bad_uri_message))
            end
          end

          context 'that do resolve to a complete url' do
            it 'makes a request to the complete url' do
              stub_request(:delete, complete_url)
                .to_return(status: 200)

              result = runnable.execute_operation(delete_operation)
              expect(result).to eq(runnable.pass_report(default_description))
            end

            context 'with specified headers' do
              before { delete_operation.requestHeader = request_header }

              it 'makes a request with specified additional headers' do
                stub_request(:delete, complete_url)
                  .with(headers: request_header_hash)
                  .to_return(status: 200)

                result = runnable.execute_operation(delete_operation)
                expect(result).to eq(runnable.pass_report(default_description))
              end
            end
          end
        end

        context 'with no variables' do
          it 'makes a request to operation.url' do
            stub_request(:delete, complete_url)
              .to_return(status: 200)

            result = runnable.execute_operation(delete_operation)
            expect(result).to eq(runnable.pass_report(default_description))
          end

          context 'with specified headers' do
            before { delete_operation.requestHeader = request_header }

            it 'makes a request with specified additional headers' do
              stub_request(:delete, complete_url)
                .with(headers: request_header_hash)
                .to_return(status: 200)

              result = runnable.execute_operation(delete_operation)
              expect(result).to eq(runnable.pass_report(default_description))
            end
          end
        end
      end

      context 'using params' do
        before do
          delete_operation.params = id
          delete_operation.resource = resource_type
        end

        context 'without defined resource' do
          before { delete_operation.resource = nil }

          it 'returns a fail report' do
            result = runnable.execute_operation(delete_operation)
            expect(result).to eq(runnable.fail_report('noResource'))
          end
        end

        context 'with defined resource' do
          context 'with variables' do
            before do
              delete_operation.resource = '${resource_type}'
              delete_operation.params = '/${id}'
            end

            context 'that do not resolve to a complete url' do
              before { runnable.tScript.variable = [] }

              it 'makes a request to the incomplete url' do
                stub_request(:delete, incomplete_url)
                  .to_return(status: 400)

                result = runnable.execute_operation(delete_operation)
                expect(result).to eq(runnable.pass_report(default_description))
              end

              context 'with specified headers' do
                before { delete_operation.requestHeader = request_header }

                it 'includes those headers in the request' do
                  stub_request(:delete, incomplete_url)
                    .with(headers: request_header_hash)
                    .to_return(status: 400)

                  result = runnable.execute_operation(delete_operation)
                  expect(result).to eq(runnable.pass_report(default_description))
                end
              end
            end

            context 'that do resolve to a complete url' do
              it 'makes a request to the complete url' do
                stub_request(:delete, complete_url)
                  .to_return(status: 200)

                result = runnable.execute_operation(delete_operation)
                expect(result).to eq(runnable.pass_report(default_description))
              end

              context 'with specified headers' do
                before { delete_operation.requestHeader = request_header }

                it 'includes those headers in the request' do
                  stub_request(:delete, complete_url)
                    .with(headers: request_header_hash)
                    .to_return(status: 200)

                  result = runnable.execute_operation(delete_operation)
                  expect(result).to eq(runnable.pass_report(default_description))
                end
              end
            end
          end

          context 'without variables' do
            it 'makes a request to the url constructed via resource and params' do
              stub_request(:delete, complete_url)
                .to_return(status: 200)

              result = runnable.execute_operation(delete_operation)
              expect(result).to eq(runnable.pass_report(default_description))
            end

            context 'with specified headers' do
              before { delete_operation.requestHeader = request_header }

              it 'makes a request with specified additional headers' do
                stub_request(:delete, complete_url)
                  .with(headers: request_header_hash)
                  .to_return(status: 200)

                result = runnable.execute_operation(delete_operation)
                expect(result).to eq(runnable.pass_report(default_description))
              end
            end
          end
        end
      end

      context 'using targetId' do
        before do
          delete_operation.targetId = targetId
          runnable.fixtures[targetId] = "FHIR::#{resource_type}".constantize.new
          runnable.id_map[targetId] = id
        end

        context 'with no corresponding fixture' do
          before { runnable.fixtures[targetId] = nil }

          it 'returns a fail report' do
            result = runnable.execute_operation(delete_operation)
            expect(result).to eq(runnable.fail_report('noTargetIdFixture'))
          end
        end

        context 'with no server id for corresponding fixture' do
          before { runnable.id_map[targetId] = nil }

          it 'returns a fail report' do
            result = runnable.execute_operation(delete_operation)
            expect(result).to eq(runnable.fail_report('noId'))
          end
        end

        it 'makes a request to the url constructed from the corresponding fixture and its server id' do
          stub_request(:delete, "#{endpoint}/#{resource_type}/#{id}")
            .to_return(status: 200)

          result = runnable.execute_operation(delete_operation)
          expect(result).to eq(runnable.pass_report(default_description))
        end

        context 'with specified headers' do
          before { delete_operation.requestHeader = request_header }

          it 'makes a request with specified additional headers' do
            stub_request(:delete, complete_url)
              .with(headers: request_header_hash)
              .to_return(status: 200)

            result = runnable.execute_operation(delete_operation)
            expect(result).to eq(runnable.pass_report(default_description))
          end
        end
      end
    end

    context 'search operation' do
      let(:search_code) do
        FHIR::Coding.new({
                           'code' => 'search',
                           'system' => system
                         })
      end
      let(:read_config) do
        {
          'description' => default_description,
          'type' => search_code
        }
      end
      let(:search_operation) { FHIR::TestScript::Setup::Action::Operation.new(read_config) }

      context 'using :get' do
        context 'using url' do
          let(:search_url) { "#{endpoint}/#{resource_type}?_id=#{id}" }
          before { search_operation.url = search_url }

          it 'makes the search request' do
            stub_request(:get, search_url)

            result = runnable.execute_operation(search_operation)
            expect(result).to eq(runnable.pass_report(default_description))
          end
        end
      end

      context 'using :post' do
      end
    end

    context 'vread operation' do
    end

    context 'updateCreate operation' do
    end

    context 'given method operation' do
      context 'with get' do
      end

      context 'with post' do
      end
    end
  end
end
