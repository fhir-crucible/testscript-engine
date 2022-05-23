require 'TestScriptRunnable'

describe TestScriptRunnable do
  let(:relative_url) { 'Patient/123' }
  let(:absolute_url) { 'https://example.com/Patient/123' }
  let(:type_coding) { FHIR::Coding.new({
    system: 'http://hl7.org/fhir/restful-interaction',
    code: 'create'
  })}
  let(:operation) { FHIR::TestScript::Setup::Action::Operation.new({
    type: type_coding,
    resourceType: "Patient"
  })}
  let(:runnable) { TestScriptRunnable.new FHIR::TestScript.new(
    {
      "resourceType": "TestScript",
      "url": "http://hl7.org/fhir/TestScript/testscript-example-history",
      "name": "TestScript-Example-History",
      "status": "draft"
    }
  )}

  describe '#extract_path' do
    context 'with url' do
      context 'absolute' do
        before { operation.url = absolute_url }

        it 'creates a path that includes that url' do
          result = runnable.extract_path operation
          expect(result).to eq(absolute_url)
        end 
      end
      
      context 'relative' do
        before { operation.url = relative_url }

        it 'creates a path that includes that url' do
          result = runnable.extract_path operation
          expect(result).to eq('Patient/123')
        end 
      end 
    end 

    context 'with targetId' do
      before { 
        operation.targetId = 'fixture-patient-create' 
        operation.resource = 'Patient'
      }
      # some sort of failure 
      it 'creates a path using targetId' do
        result = runnable.extract_path operation
      end 
  end 

    context 'with params' do
      before {
        operation.params = '/${createResourceId}'
      }
      it 'creates a path with params' do
        result = runnable.extract_path operation
      end 
    end

    context 'with sourceId' do
      before { 
        operation.sourceId = 'fixture-patient-create' 
      }
      it 'creates a path using sourceId' do
        result = runnable.extract_path operation
      end 

    end 
  end 
end 