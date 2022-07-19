# frozen_string_literal: true

require 'TestScriptRunnable'

describe TestScriptRunnable do
  let(:operation) { FHIR::TestScript::Setup::Action::Operation.new(encodeRequestUrl: true) }

  before(:all) do
    @req_type = :get
    @serverId = 'server_id'
    @sourceId = 'source_id'
    @targetId = 'target_id'
    @url = 'http://example.com'
    @resource = FHIR::Patient.new
    @absolute_url = "#{@url}/#{@path}"
    @path = "#{@resource_path}/#{@serverId}"
    @resourceType = @resource.resourceType.to_s
    @params = '?_outputFormat=application/ndjson'
    @resource_path = @resource.resourceType.to_s
    @allergy_resource = FHIR::AllergyIntolerance.new
    @allergy_resource_path = @allergy_resource.resourceType.to_s
    @allergy_path = "#{@allergy_resource_path}/#{@serverId}"
    @response = { code: 200, headers: {}, body: @allergy_resource.to_json }
    @runnable = TestScriptRunnable.new FHIR::TestScript.new(
      {
        "resourceType": 'TestScript',
        "url": 'http://hl7.org/fhir/TestScript/testscript-example-history',
        "name": 'TestScript-Example-History',
        "status": 'draft'
      }
    )
    @runnable.id_map[@targetId] = @serverId
    @runnable.fixtures[@sourceId] = @resource
    @runnable.response_map[@targetId] = @response
  end

  describe '.extract_path' do
    context 'given url' do
      before do
        operation.url = @absolute_url
        allow(@runnable).to receive(:replace_variables).and_return(@absolute_url)
      end

      it 'returns url' do
        result = @runnable.extract_path(operation, @req_type)

        expect(result).to eq(@absolute_url)
      end
    end

    context 'given params' do
      before do
        operation.params = @params
        operation.resource = @resourceType
      end

      context 'with :get' do
        it 'returns [resourceType][params] path' do
          result = @runnable.extract_path(operation, @req_type)

          expect(result).to eq("#{@resourceType}#{@params}")
        end

        context 'and contentType' do
          before { operation.contentType = 'some_content' }

          it 'returns [resourceType][params][&_format=mime] in path' do
            result = @runnable.extract_path(operation, @req_type)

            expect(result).to eq("#{@resourceType}#{@params}&_format=some_content")
          end

          context 'without resource' do
            it 'returns [params][&_format=mime] in system-level path' do
              operation.resource = nil
              result = @runnable.extract_path(operation, @req_type)

              expect(result).to eq("#{@params}&_format=some_content")
            end
          end
        end

        context 'without resource' do
          it 'returns [params] in system-level path' do
            operation.resource = nil
            result = @runnable.extract_path(operation, @req_type)

            expect(result).to eq(@params)
          end
        end
      end

      context 'with :post' do
        it 'returns /_search[resourceType][params] path' do
          result = @runnable.extract_path(operation, :post)

          expect(result).to eq("#{@resourceType}/_search#{@params}")
        end

        context 'and contentType' do
          before { operation.contentType = 'some_content' }

          it 'returns [resourceType][params][&_format=mime] in path' do
            result = @runnable.extract_path(operation, :post)

            expect(result).to eq("#{@resourceType}/_search#{@params}&_format=some_content")
          end

          context 'without resource' do
            it 'returns [params][&_format=mime] in system-level path' do
              operation.resource = nil
              result = @runnable.extract_path(operation, :post)

              expect(result).to eq("/_search#{@params}&_format=some_content")
            end
          end
        end

        context 'without resource' do
          it 'returns [params] in system-level path' do
            operation.resource = nil
            result = @runnable.extract_path(operation, :post)

            expect(result).to eq("/_search#{@params}")
          end
        end
      end
    end

    context 'given targetId' do
      context 'denoting nothing' do
        before { operation.targetId = 'not_target_id' }

        it 'returns nil' do
          result = @runnable.extract_path(operation, @req_type)

          expect(result).to be_nil
        end
      end

      context 'denoting dynamic id' do
        before { operation.targetId = @targetId }

        it 'returns [resourceType]/[id] path' do
          result = @runnable.extract_path(operation, @req_type)

          expect(result).to eq(@allergy_path)
        end
      end
    end

    context 'given sourceId' do
      context 'denoting nothing' do
        before { operation.sourceId = 'not_source_id' }

        it 'returns nil' do
          result = @runnable.extract_path(operation, @req_type)

          expect(result).to be_nil
        end
      end

      context 'denoting static fixture' do
        before { operation.sourceId = @sourceId }

        it 'returns [resourceType] path' do
          result = @runnable.extract_path(operation, @req_type)

          expect(result).to eq(@resource_path)
        end
      end

      context 'denoting response body' do
        before { operation.sourceId = @targetId }

        it 'returns [resourceType] path' do
          result = @runnable.extract_path(operation, @req_type)

          expect(result).to eq(@allergy_resource_path)
        end
      end
    end
  end
end
