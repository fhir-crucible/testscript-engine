require 'TestScriptRunnable'

describe TestScriptRunnable do
  let(:id) { '123' } 
  let(:req_type) { :get }
  let(:contentType) { 'xml' }
  let(:sourceId) { 'sourceId' }
  let(:targetId) { 'patient-create' }
  let(:resource) { FHIR::Patient.new }
  let(:relative_url) { 'Patient/123' }
  let(:params) { '?_lastUpdated=gt2010-10-01' }
  let(:client) { FHIR::Client.new(absolute_url) }
  let(:absolute_url) { 'https://example.com/Patient/123' }
  let(:clientReply) { FHIR::ClientReply.new(nil, nil, client) }
  let(:operation) { FHIR::TestScript::Setup::Action::Operation.new }
  let(:runnable) { TestScriptRunnable.new FHIR::TestScript.new(
    {
      "resourceType": "TestScript",
      "url": "http://hl7.org/fhir/TestScript/testscript-example-history",
      "name": "TestScript-Example-History",
      "status": "draft"
    }
  )}

  describe '#extract_path' do
    context 'with absolute url' do
      before { allow(runnable).to receive(:replace_variables).and_return(absolute_url) }

      it 'creates the absolute path' do
        operation.url = absolute_url
        expect(runnable.extract_path(operation, req_type)).to eq(absolute_url)
      end 
    end

    context 'with relative url' do
      before { allow(runnable).to receive(:replace_variables).and_return(relative_url) }

      it 'creates the relative path' do
        operation.url = relative_url
        expect(runnable.extract_path(operation, req_type)).to eq(relative_url)
      end 
    end 

    context 'with params' do
      before do
        operation.params = params
        operation.resource = resource.resourceType
        allow(runnable).to receive(:replace_variables).and_return(params)
        allow(runnable).to receive(:requires_type).and_return(false)
      end 

      context 'for GET search' do
        context 'with resource' do
          it 'creates the /[type][?parameters] path' do 
            expect(runnable.extract_path(operation, req_type)).to eq("#{resource.resourceType}#{params}")
          end 
        end 
  
        context 'without resource' do
          before { operation.resource = nil }

          it 'creates the [?parameters] path' do 
            expect(runnable.extract_path(operation, req_type)).to eq("#{params}")
          end 
        end 

        context 'with mime-type' do
          before { operation.contentType = contentType }

          it 'creates the /[type][?parameters]{&_format=[mime-type]} path' do
            expect(runnable.extract_path(operation, req_type)).to eq("#{resource.resourceType}#{params}{&_format=application/fhir+#{contentType}}")
          end 
        end 
      end 

      context 'for POST search' do
        let(:req_type) { :post }
        
        context 'with resource' do  
          it 'creates the [type]/_search[?parameters] path' do 
            expect(runnable.extract_path(operation, req_type)).to eq("#{resource.resourceType}/_search#{params}")
          end 
        end 
  
        context 'without resource' do         
          before { operation.resource = nil }

          it 'creates the /_search[?parameters] path' do 
            expect(runnable.extract_path(operation, req_type)).to eq("/_search#{params}")
          end 
        end 

        context 'with mime-type' do
          before { operation.contentType = contentType }

          it 'creates the [type]/_search[?parameters]{&_format=[mime-type]} path' do
            expect(runnable.extract_path(operation, req_type)).to eq("#{resource.resourceType}/_search#{params}{&_format=application/fhir+#{contentType}}")
          end 
        end 
      end 

      context 'with resource type required' do
        before { allow(runnable).to receive(:requires_type).and_return(true) }

        context 'with resource' do
          it 'returns /_search[?parameters] path' do
            expect(runnable.extract_path(operation, req_type)).to eq("#{resource.resourceType}#{params}")
          end
        end 

        context 'without resource' do
          before { operation.resource = nil }

          it 'returns nil' do
            expect(runnable.extract_path(operation, req_type)).to eq(nil)
          end
        end 
      end 
    end 

    context 'with targetId' do
      before do
        operation.targetId = targetId
        clientReply.resource = resource
        runnable.response_map[targetId] = clientReply
      end 

      context 'denoting Resource A' do
        before { runnable.id_map[targetId] = id }

        it 'creates path to Resource A' do
          expect(runnable.extract_path(operation, req_type)).to eq("#{resource.resourceType}/#{id}")
        end 
      end

      context 'not denoting some Resource A' do
        it 'returns nil' do
          expect(runnable.extract_path(operation, req_type)).to eq(nil)
        end 
      end
    end 

    context 'with sourceId' do
      before { operation.sourceId = sourceId }

      context 'denoting some Fixture A' do
        before { runnable.fixtures[sourceId] = resource }

        it 'returns path to create Fixture A' do
          expect(runnable.extract_path(operation, req_type)).to eq("#{resource.resourceType}")
        end 
      end 

      context 'not denoting some Fixture A' do
        before { runnable.fixtures[sourceId] = nil }

        it 'returns nil' do
          expect(runnable.extract_path(operation, req_type)).to eq(nil)
        end 
      end 
    end 
  end 
end 