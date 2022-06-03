# frozen_string_literal: true

require 'TestScriptRunnable'

describe TestScriptRunnable do
  let(:url) { 'https://example.com' }
  let(:accept_pair) { { 'Accept' => accept_value } }
  let(:accept_value) { FHIR::Formats::ResourceFormat::RESOURCE_JSON }
  let(:content_type_pair) { { 'Content-Type' => content_type_value } }
  let(:content_type_value) { FHIR::Formats::ResourceFormat::RESOURCE_XML }
  let(:request_headers) do
    [FHIR::TestScript::Setup::Action::Operation::RequestHeader.new(field: 'Retry-After', value: '60'),
     FHIR::TestScript::Setup::Action::Operation::RequestHeader.new(field: 'Location', value: url)]
  end
  let(:request_headers_pair) { { 'Retry-After' => '60', 'Location' => url } }
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

  context '#extract_headers' do
    context 'given no header attributes' do
      it 'returns nil' do
        expect(runnable.extract_headers(operation)).to eq(nil)
      end
    end

    context 'given accept' do
      before { operation.accept = accept_value }

      context ' == json' do
        before { operation.accept = 'json' }

        it 'returns JSON ResourceFormat' do
          expect(runnable.extract_headers(operation)).to eq(accept_pair)
        end
      end

      it 'returns accept header' do
        expect(runnable.extract_headers(operation)).to eq(accept_pair)
      end
    end

    context 'given contentType' do
      before { operation.contentType = content_type_value }

      context ' == xml' do
        before { operation.contentType = 'xml' }

        it 'returns XML ResourceFormat' do
          expect(runnable.extract_headers(operation)).to eq(content_type_pair)
        end
      end

      it 'returns accept header' do
        expect(runnable.extract_headers(operation)).to eq(content_type_pair)
      end
    end

    context 'given requestHeader' do
      before { operation.requestHeader = request_headers }

      it 'returns each request header field/value pair' do
        expect(runnable.extract_headers(operation)).to eq(request_headers_pair)
      end
    end

    context 'given accept, contentType, and a requestHeader' do
      before do
        operation.accept = accept_value
        operation.contentType = content_type_value
        operation.requestHeader = request_headers
      end

      context 'containing accept and contentType' do
        before do
          operation.requestHeader = [
            FHIR::TestScript::Setup::Action::Operation::RequestHeader.new(
              field: 'Accept', value: 'json'
            ),
            FHIR::TestScript::Setup::Action::Operation::RequestHeader.new(
              field: 'Content-Type', value: 'xml'
            )
          ]
        end

        it 'overwrites using requestHeader values' do
          expect(runnable.extract_headers(operation)).to eq({ 'Accept' => 'json', 'Content-Type' => 'xml' })
        end
      end

      it 'returns all the denoted headers' do
        expect(runnable.extract_headers(operation))
          .to eq(accept_pair.merge(content_type_pair).merge(request_headers_pair))
      end
    end
  end
end
