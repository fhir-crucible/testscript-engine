require 'TestScriptRunnable'

describe TestScriptRunnable do
  let(:relative_url) { 'Patient/123' }
  let(:absolute_url) { 'https://example.com/Patient/123' }
  let(:type_coding) { FHIR::Coding.new({
    system: 'http://hl7.org/fhir/restful-interaction',
    code: 'create'
  })}
  let(:operation) { FHIR::TestScript::Setup::Action::Operation.new({
    type: type_coding
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

        it 'creates a path that includes absolute url' do
          result = runnable.extract_path operation
          expect(result).to eq(absolute_url)
        end 
      end
      
      context 'relative' do
        before { operation.url = relative_url }

        it 'creates a path that includes relative url' do
          result = runnable.extract_path operation
          expect(result).to eq(relative_url)
        end 
      end 
    end 

    context 'with targetId' do
      before { operation.targetId = 'fixture-patient-create' }
      # some sort of failure 
      it 'creates a path with targetId' do
        result = runnable.extract_path operation
      end 
  end 

    context 'with params' do
      before { operation.params = '${createResourceId}' }
      # some sort of failure 
      it 'creates a path with targetId' do
        result = runnable.extract_path operation
      end 
    end

    context 'with sourceId' do
      before { operation.sourceId = 'fixture-patient-create' }
      # some sort of failure 
      it 'creates a path with sourceId' do
        result = runnable.extract_path operation
      end 
    end 
  end 
end 