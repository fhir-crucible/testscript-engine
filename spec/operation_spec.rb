# frozen_string_literal: true

require 'Operation'

class OperationsTestClass
  include Operation

  attr_accessor :client

  def replace_variables(input)
    input
  end

  def storage(operation); end

  def pass(*args); end

  def fixtures
    @fixtures ||= {}
  end

  def response_map
    @response_map ||= {}
  end

  def get_resource(id)
    fixtures[id] || response_map[id]&.[](:body)
  end
end

describe Operation do
  before(:all) do
    @vid = '456'
    @source_id = 'source_id'
    @resource_type = 'Patient'
    @url = 'https://example.com'
    @tester = OperationsTestClass.new
    @tester.client = FHIR::Client.new(@url)
    @resource = FHIR.from_contents(File.read('spec/fixtures/example_patient.json'))
    @tester.fixtures[@source_id] = @resource
    @id = @tester.fixtures[@source_id].id
  end
  before(:each) do
    @tester.fixtures[@source_id] = @resource.deep_dup
    @operation = FHIR::TestScript::Setup::Action::Operation.new
  end

  describe '.execute' do
    before { @operation.url = '/Patient/123' }

    it 'supports GET operation' do
      stub_request(:get, "#{@url}#{@operation.url}")

      @operation.local_method = 'get'

      @tester.execute(@operation)
    end

    it 'supports POST operation' do
      stub_request(:post, "#{@url}#{@operation.url}")

      @operation.local_method = 'post'
      @operation.sourceId = @source_id

      @tester.execute(@operation)
    end

    it 'supports PUT operation' do
      stub_request(:put, "#{@url}#{@operation.url}")

      @operation.local_method = 'put'
      @operation.sourceId = @source_id

      @tester.execute(@operation)
    end

    it 'supports DELETE operation' do
      stub_request(:delete, "#{@url}#{@operation.url}")

      @operation.local_method = 'delete'

      @tester.execute(@operation)
    end

    it 'supports PATCH operation' do
      stub_request(:patch, "#{@url}#{@operation.url}")

      @operation.local_method = 'patch'
      @operation.sourceId = @source_id

      @tester.execute(@operation)
    end

    it 'supports HEAD operation' do
      stub_request(:head, "#{@url}#{@operation.url}")

      @operation.local_method = 'head'

      @tester.execute(@operation)
    end
  end

  describe '.build_request' do
    it 'catches standard errors' do
      allow(@tester).to receive(:build_request).and_return(['get'])

      expect { @tester.execute(@operation) }
        .to raise_exception(StandardError)
    end
  end

  describe '.get_interaction' do
    it 'returns the method, if method' do
      @operation.local_method = 'patch'

      result = @tester.get_interaction(@operation)

      expect(result).to be(@operation.local_method)
    end

    it 'returns the type mapping, if type' do
      @operation.type = FHIR::Coding.new(code: 'history-type')

      result = @tester.get_interaction(@operation)

      expect(result).to eq('get')
    end

    it 'raises an OperationException' do
      expect { @tester.get_interaction(@operation) }
        .to raise_exception(Operation::OperationException)
    end
  end

  describe '.get_path' do
    it 'raises an excepion if no url, params, targetId, or source_id' do
      @operation.type = FHIR::Coding.new(code: 'create')

      expect { @tester.get_path(@operation) }
        .to raise_exception(Operation::OperationException)
    end

    context 'with operation.url' do
      it 'returns url' do
        @operation.url = "/Patient/#{@id}"

        expect(@tester.get_path(@operation)).to eq(@operation.url)
      end
    end

    context 'with operation.params' do
      before do
        @operation.params = "/#{@id}"
        @operation.resource = @resource_type
      end

      it 'raises an exception if resource required and not given' do
        @operation.resource = nil
        @operation.type = FHIR::Coding.new(code: 'create')

        expect { @tester.get_path(@operation) }
          .to raise_exception(Operation::OperationException)
      end

      it "returns '/[type]/[id]' path for READ" do
        @operation.type = FHIR::Coding.new(code: 'read')

        result = @tester.get_path(@operation)

        expect(result).to eq("#{@resource_type}/#{@id}")
      end

      it "returns '/[type]/[id]/_history/[vid]' path for VREAD" do
        @operation.params = "/#{@id}/_history/456"
        @operation.type = FHIR::Coding.new(code: 'vread')

        result = @tester.get_path(@operation)

        expect(result).to eq("#{@resource_type}/#{@id}/_history/456")
      end

      it "returns '/[type]/[id]' path for UPDATE" do
        @operation.type = FHIR::Coding.new(code: 'update')

        result = @tester.get_path(@operation)

        expect(result).to eq("#{@resource_type}/#{@id}")
      end

      it "returns '/[type]/[id]' path for PATCH" do
        @operation.type = FHIR::Coding.new(code: 'patch')

        result = @tester.get_path(@operation)

        expect(result).to eq("#{@resource_type}/#{@id}")
      end

      it "returns '/[type]/[id]' path for DELETE" do
        @operation.type = FHIR::Coding.new(code: 'delete')

        result = @tester.get_path(@operation)

        expect(result).to eq("#{@resource_type}/#{@id}")
      end

      it "returns '/[type]{?[parameters]}' path for SEARCH" do
        @operation.params = '?active=true'
        @operation.type = FHIR::Coding.new(code: 'search')

        result = @tester.get_path(@operation)

        expect(result).to eq("#{@resource_type}#{@operation.params}")
      end

      it "returns '/[type]{?[parameters]}' path for SEARCH by POST" do
        @operation.params = '/_search?active=true'
        @operation.local_method = 'post'

        result = @tester.get_path(@operation)

        expect(result).to eq("#{@resource_type}#{@operation.params}")
      end

      it "returns '/{?[parameters]}' path for SEARCH" do
        @operation.resource = nil
        @operation.params = '/?active=true'
        @operation.type = FHIR::Coding.new(code: 'search')

        result = @tester.get_path(@operation)

        expect(result).to eq(@operation.params)
      end

      it "returns '/{?[parameters]}' path for SEARCH by POST" do
        @operation.resource = nil
        @operation.params = '/_search?active=true'
        @operation.type = FHIR::Coding.new(code: 'search')

        result = @tester.get_path(@operation)

        expect(result).to eq(@operation.params)
      end

      it "returns '/[type]/[id]' path for CAPABILITIES" do
        @operation.params = '/metadata?mode=mode'
        @operation.type = FHIR::Coding.new(code: 'capabilities')

        result = @tester.get_path(@operation)

        expect(result).to eq("#{@resource_type}#{@operation.params}")
      end

      it "returns '/[type]/[id]/_history' path for HISTORY" do
        @operation.params = "/#{@id}/_history"
        @operation.type = FHIR::Coding.new(code: 'history')

        result = @tester.get_path(@operation)

        expect(result).to eq("#{@resource_type}/#{@id}/_history")
      end

      it "returns '/[type]/_history' path for HISTORY" do
        @operation.params = '/_history'
        @operation.type = FHIR::Coding.new(code: 'history')

        result = @tester.get_path(@operation)

        expect(result).to eq("#{@resource_type}/_history")
      end

      it "returns '/_history' path for HISTORY" do
        @operation.resource = nil
        @operation.params = '/_history'
        @operation.type = FHIR::Coding.new(code: 'history')

        result = @tester.get_path(@operation)

        expect(result).to eq('/_history')
      end
    end

    context 'with operation.targetId' do
      before do
        @operation.targetId = @source_id
        @tester.fixtures[@source_id].meta.versionId = @vid
      end

      it 'raises an error if no corresponding fixture or response' do
        @operation.targetId = 'no_corresponding_id'

        expect { @tester.get_path(@operation) }
          .to raise_exception(Operation::OperationException)
      end

      it 'raises an error if id not present for VREAD' do
        @tester.fixtures[@source_id].id = nil

        @operation.type = FHIR::Coding.new(code: 'vread')

        expect { @tester.get_path(@operation) }
          .to raise_exception(Operation::OperationException)
      end

      it 'raises an error if vid not present for VREAD' do
        @tester.fixtures[@source_id].meta.versionId = nil

        @operation.type = FHIR::Coding.new(code: 'vread')

        expect { @tester.get_path(@operation) }
          .to raise_exception(Operation::OperationException)
      end

      it "returns '[type]/[id]' path for READ" do
        @operation.type = FHIR::Coding.new(code: 'read')

        result = @tester.get_path(@operation)

        expect(result).to eq("#{@resource_type}/#{@id}")
      end

      it "returns '/[type]/[id]/_history/[vid]' path for VREAD" do
        @operation.type = FHIR::Coding.new(code: 'vread')

        result = @tester.get_path(@operation)

        expect(result).to eq("#{@resource_type}/#{@id}/_history/#{@vid}")
      end

      it "returns '/[type]/[id]' path for UPDATE" do
        @operation.type = FHIR::Coding.new(code: 'update')

        result = @tester.get_path(@operation)

        expect(result).to eq("#{@resource_type}/#{@id}")
      end

      it "returns '/[type]/[id]' path for PATCH" do
        @operation.type = FHIR::Coding.new(code: 'patch')

        result = @tester.get_path(@operation)

        expect(result).to eq("#{@resource_type}/#{@id}")
      end

      it "returns '/[type]/[id]' path for DELETE" do
        @operation.type = FHIR::Coding.new(code: 'delete')

        result = @tester.get_path(@operation)

        expect(result).to eq("#{@resource_type}/#{@id}")
      end

      it "returns '/[type]/[id]/_history' path for HISTORY" do
        @operation.type = FHIR::Coding.new(code: 'history')

        result = @tester.get_path(@operation)

        expect(result).to eq("#{@resource_type}/#{@id}/_history")
      end
    end

    context 'with operation.source_id' do
      before { @operation.sourceId = @source_id }

      it 'raises an error if no corresponding fixture or response' do
        @operation.sourceId = 'no_corresponding_id'

        expect { @tester.get_path(@operation) }
          .to raise_exception(Operation::OperationException)
      end

      it "returns '[type]' path for CREATE" do
        @operation.type = FHIR::Coding.new(code: 'create')

        result = @tester.get_path(@operation)

        expect(result).to eq(@resource_type.to_s)
      end

      it 'returns empty path for BATCH' do
        @operation.type = FHIR::Coding.new(code: 'batch')

        result = @tester.get_path(@operation)

        expect(result).to eq('')
      end

      it 'returns empty path for TRANSACTION' do
        @operation.type = FHIR::Coding.new(code: 'transaction')

        result = @tester.get_path(@operation)

        expect(result).to eq('')
      end
    end
  end

  describe '.get_payload' do
    it 'raises an error if no corresponding fixture or response and body required' do
      @operation.local_method = 'post'
      @operation.sourceId = 'no_corresponding_id'

      expect { @tester.get_payload(@operation, 'post') }
        .to raise_exception(Operation::OperationException)
    end

    it 'returns nil if no corresponding fixture or response and body not required' do
      @operation.sourceId = 'no_corresponding_id'

      result = @tester.get_payload(@operation, 'get')

      expect(result).to be(nil)
    end

    it 'returns the body' do
      @operation.sourceId = @source_id

      result = @tester.get_payload(@operation, 'post')

      expect(result).to eq(@tester.fixtures[@source_id])
    end
  end

  describe '.get_headers' do
    let(:headers) do
      {
        'content-type' => 'application/fhir+json',
        'accept' => 'application/fhir+json'
      }
    end

    it 'by default sets Accept and Content-Type to application/fhir+json' do
      result = @tester.get_headers(@operation)

      expect(result).to eq(headers)
    end

    it 'sets Accept and Content-Type to application/fhir+json if given bad values' do
      @operation.contentType = 'jargon'
      @operation.accept = 'more jargon'

      result = @tester.get_headers(@operation)

      expect(result).to eq(headers)
    end

    it 'updates Accept and Content-Type to application/fhir+xml as specified' do
      @operation.contentType = 'xml'
      @operation.accept = 'xml'

      headers['content-type'] = 'application/fhir+xml'
      headers['accept'] = 'application/fhir+xml'

      result = @tester.get_headers(@operation)

      expect(result).to eq(headers)
    end

    it 'replaces Accept and Content-Type as specified in requestHeader' do
      @operation.requestHeader = [
        FHIR::TestScript::Setup::Action::Operation::RequestHeader.new(field: 'Accept', value: 'xml'),
        FHIR::TestScript::Setup::Action::Operation::RequestHeader.new(field: 'Content-Type', value: 'xml')
      ]

      headers['content-type'] = 'xml'
      headers['accept'] = 'xml'

      result = @tester.get_headers(@operation)

      expect(result).to eq(headers)
    end

    it 'adds headers specified in requestHeader' do
      @operation.requestHeader = [
        FHIR::TestScript::Setup::Action::Operation::RequestHeader.new(field: 'Authorization', value: 'token'),
        FHIR::TestScript::Setup::Action::Operation::RequestHeader.new(field: 'Expires', value: '1600')
      ]

      headers['authorization'] = 'token'
      headers['expires'] = '1600'

      result = @tester.get_headers(@operation)

      expect(result).to eq(headers)
    end
  end
end
