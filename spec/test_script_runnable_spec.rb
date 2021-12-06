# TODO: Break unit tests for different classes into seperate files 
require "TestScriptRunnable.rb"

describe TestScriptRunnable do

  @tScript = nil
  @runnable = nil

  def create_runnable(curr_test)
    @tScript = FHIR.from_contents(File.read("./spec/spec_tScripts/#{curr_test}_tScript_spec.json"))
    @runnable = TestScriptRunnable.new(@tScript)
  end 

  describe '.new' do
    context 'given an invalid TestScript' do 
      it 'logs an error message and returns nil' do        
        expect(FHIR.logger).to receive(:error).with('[.initialize] Received invalid TestScript: can not initialize TestScriptRunnable.')

        @runnable = TestScriptRunnable.new(nil)
        expect(@runnable.nil?)
      end 
    end 

    context 'given a valid TestScript' do
      it 'returns an instance of the TestScriptRunnable class' do
        create_runnable('new')
        expect(@runnable.is_a?(TestScriptRunnable))
      end 
    end 
  end 

  describe '.load_fixtures' do
    before do
      create_runnable('load_fixtures')
    end 

    context 'given a TestScript without fixtures' do
      it 'leaves the @fixtures hash untouched' do
        @runnable.tScript.fixture = nil
        @runnable.load_fixtures

        expect(@runnable.fixtures.nil?)
      end 
    end

    context 'given a TestScript with fixtures' do
      it 'stores those fixtures (by their id) in the @fixture hash' do 
        @runnable.load_fixtures

        @tScript.fixture.each do |fixture|
          expect(@runnable.fixtures.has_key?(fixture.id))
        end 
      end 

      context 'that are not autocreated' do
        it 'does not store those fixtures in @autocreate' do 
          @runnable.load_fixtures

          @tScript.fixture.each do |fixture|
            expect(@runnable.autocreate.include? fixture.id).to be_falsey if fixture.autocreate == false
          end 
        end 
      end 

      context 'that are not autodeleted' do
        it 'does not store those fixtures in @autodelete' do 
          @runnable.load_fixtures

          @tScript.fixture.each do |fixture|
            expect(@runnable.autodelete.include? fixture.id).to be_falsey if fixture.autodelete == false
          end 
        end 
      end 

      context 'that are autocreated' do
        it 'does store those fixtures in the @autocreate array' do 
          @runnable.load_fixtures
          
          @tScript.fixture.each do |fixture|
            expect(@runnable.autocreate.include? fixture.id) if fixture.autocreate
          end 
        end  
      end 

      context 'that are autodeleted' do
        it 'does store those fixtures in the @autodelete array only' do 
          @runnable.load_fixtures

          @tScript.fixture.each do |fixture|
            expect(@runnable.autodelete.include? fixture.id) if fixture.autodelete
          end 
        end
      end 
    end
  end 

  #TODO: get_reference unit tests

  describe '.execute_operation' do
    before do
      create_runnable('execute_operation')
    end 

    context 'given an invalid operation input' do
      it 'logs a warning message' do 
        expect(FHIR.logger).to receive(:warn).with('[.execute_operation] Received invalid operation: can not execute.')

        @runnable.execute_operation(nil)
      end 
      it 'returns a failing TestReport element and its cause' do         
        result = @runnable.execute_operation(nil)

        expect(result.result).to eq('fail')
        expect(result.message).to eq('[.execute_operation] Received invalid operation: can not execute.')
      end 
    end 

    context 'given a valid operation input' do
      context 'that is empty' do
        it 'returns a passing TestReport element' do 
          operation = FHIR::TestScript::Setup::Action::Operation.new
          result = @runnable.execute_operation(operation)

          expect(result.result).to eq('pass')
          expect(result.message).to eq('Unspecified description.')
        end 
      end 
      context 'of type [read]' do 
        context 'using targetId' do
          context 'without updated @fixtures' do 
            it 'returns a failing TestReport element' do
              read_operation = @tScript.test[0].action[0].operation
              result = @runnable.execute_operation(read_operation)

              expect(result.result).to eq('fail')
              expect(result.message).to eq('Read the patient resource on the test server using the id from fixture-patient-create. Prevent URL encoding of the request.')
            end 
          end
          context 'without updated @id_map' do 
            it 'returns a failing TestReport element' do
              read_operation = @tScript.test[0].action[0].operation
              result = @runnable.execute_operation(read_operation)

              expect(result.result).to eq('fail')
              expect(result.message).to eq('Read the patient resource on the test server using the id from fixture-patient-create. Prevent URL encoding of the request.')
            end 
          end
          context 'with updated @fixtures and @id_map and' do 
            context 'with target resource in server' do
              it 'returns a passing TestReport element' do
                read_operation = @tScript.test[0].action[0].operation
                @runnable.fixtures[read_operation.targetId] = FHIR::Patient.new
                @runnable.id_map[read_operation.targetId] = 1
                @runnable.execute_operation(read_operation)
                # Create the resource manually @tScript
              end 
            end 
            context 'without target resource in server' do
              it 'returns a failing TestReport element' do

              end 
            end 
          end
        end 
        context 'using url' do
        end 
        context 'catch all' do
        end 
      end 
      context 'of type [vread]' do 
      end 
      context 'of type [search]' do
      end 
      context 'of type [history]' do
      end 
      context 'of type [create]' do
      end 
      context 'of type [update, updateCreate]' do
      end 
      context 'of type [transaction]' do
      end 
      context 'of type [conformance]' do
      end 
      context 'of type [delete]' do
      end 
      context 'of type [$expand, expand]' do
      end 
      context 'of type [$validate, validate]' do
      end 
      context 'of type [$validate-code, validate-code]' do
      end 
      context 'of type [empty]' do
      end 
    end 
  end 

  #TODO: handle_response

  #TODO: judge_response

  #TODO: Replace variable

  #TODO: handle_assertion unit tests

end 