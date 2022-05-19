require 'TestScriptRunnable'

describe TestScriptRunnable do
  let(:relative_url) { ' ' }
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

        it 'creates a path that includes that url' do
          result = runnable.extract_path operation
          expect(result).to eq(absolute_url)
        end 
      end
      
      context 'relative' do
        before { operation.url = relative_url }

        it 'creates a path that includes that url' do

        end 
      end 
    end 

    context 'with targetId' do
      # some sort of failure 
    end 

    context 'with params' do

    end

    context 'with sourceId' do

    end 
  end 
end 