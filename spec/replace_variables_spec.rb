require 'pry'
require 'TestScriptRunnable'

describe TestScriptRunnable do
  let(:vname) { 'variable' }
  let(:vname1) { 'variable_one' }
  let(:vname2) { 'variable_two' }
  let(:vexp) { 'variable_expression' }
  let(:vexp1) { 'variable_one_expression' }  
  let(:vexp2) { 'variable_two_expression' }
  let(:vdefault) { 'variable_defaultVal' }
  let(:vdefault1) { 'variable_one_defaultVal' }
  let(:vdefault2) { 'variable_two_defaultVal' }
  let(:vreplacement) { 'variable_replacement' }
  let(:vreplacement1) { 'variable_one_replacement' }
  let(:vreplacement2) { 'variable_two_replacement' }
  let(:sourceId) { 'var_source_id' }

  let(:var) { FHIR::TestScript::Variable.new({
    name: vname,
    expression: vexp,
    sourceId: sourceId,
    defaultValue: vdefault, 
  })}
  let(:var1) { FHIR::TestScript::Variable.new({
    name: vname1,
    expression: vexp1,
    defaultValue: vdefault1
  })}
  let(:var2) { FHIR::TestScript::Variable.new({
    name: vname2,
    expression: vexp2,
    defaultValue: vdefault2
  })}

  let(:runnable) { TestScriptRunnable.new FHIR::TestScript.new(
    {
      "resourceType": "TestScript",
      "url": "http://hl7.org/fhir/TestScript/testscript-example-history",
      "name": "TestScript-Example-History",
      "status": "draft",
      "variable": [var, var1, var2]
    })
  }

  let(:client) { FHIR::Client.new('https://example.com') }
  let(:headers) { { :headers => { 'content-type' => vreplacement } } }
  let(:client_reply) { FHIR::ClientReply.new(nil, headers, client) }

  let(:input) { "/${#{vname}}/id" }
  let(:output) { "/#{vreplacement}/id" }
  let(:default_output) { "/#{vdefault}/id" }
  let(:multi_place_input) { "/${#{vname}}/${#{vname1}}/${#{vname2}}" }
  let(:multi_match_input) { "/${#{vname}}/${#{vname}}" }

  describe '#replace_variables' do
    before { runnable.response_map[sourceId] = client_reply }

    context 'given no placeholder' do
      it 'returns input' do
        expect(runnable.replace_variables('non-var')).to eq('non-var')
      end
    end

    context 'given placeholder' do
      context 'without match' do
        it 'returns input' do
          expect(runnable.replace_variables('${non-var}')).to eq('${non-var}')
        end
      end
      
      context 'with match' do
        context 'and expression' do
          context 'that resolves' do
            before { allow(runnable).to receive(:evaluate_expression).and_return(vreplacement) }
            
            it 'returns replaced input' do
              expect(runnable.replace_variables(input)).to eq(output)
            end 
          end 

          context 'that does not resolve' do
            before { allow(runnable).to receive(:evaluate_expression).and_return(nil) }
            
            context 'but does have defaultValue' do
              it 'returns replaced input, with default' do
                expect(runnable.replace_variables(input)).to eq(default_output)
              end 
            end 

            context 'and does not have defaultValue' do
              before { runnable.script.variable.first.defaultValue = nil }
              
              it 'returns input' do
                expect(runnable.replace_variables(input)).to eq(input)
              end 
            end 
          end 
        end

        context 'and headerField' do
          before do 
            runnable.script.variable.first.headerField = 'Content-Type' 
            runnable.script.variable.first.expression = nil
          end

          context 'that resolves' do
            it 'returns replaced input' do
              expect(runnable.replace_variables(input)).to eq(output)
            end 
          end 

          context 'that does not resolve' do
            context 'because !sourceId' do
              before { runnable.script.variable.first.sourceId = nil }

              it 'returns replaced input, with default' do
                expect(runnable.replace_variables(input)).to eq(default_output)
              end 
            end 

            context 'since no mapped response' do
              before { runnable.response_map[sourceId] = nil }

              it 'returns replaced default input' do
                expect(runnable.replace_variables(input)).to eq(default_output)
              end 
            end 

            context 'since no response' do
              before { runnable.response_map[sourceId].response = nil }

              it 'returns replaced default input' do
                expect(runnable.replace_variables(input)).to eq(default_output)
              end 
            end 

            context 'since no response headers' do
              before { runnable.response_map[sourceId].response[:headers] = nil }

              it 'returns replaced default input' do
                expect(runnable.replace_variables(input)).to eq(default_output)
              end 
            end 

            context 'since no matching header' do
              before { runnable.response_map[sourceId].response[:headers] = { 'bad_key' => 'bad_val' } }

              it 'returns replaced default input' do
                expect(runnable.replace_variables(input)).to eq(default_output)
              end 
            end 
          end 
        end

        context 'and path' do
          before do 
            runnable.script.variable.first.path = 'some_path'
            runnable.script.variable.first.expression = nil
          end 

          context 'yields !nil' do
            before { allow(runnable).to receive(:evaluate_path).and_return(vreplacement) }

            it 'returns replaced input' do
              expect(runnable.replace_variables(input)).to eq(output)
            end 
          end 

          context 'yields nil' do
            it 'returns replaced default input' do
              expect(runnable.replace_variables(input)).to eq(default_output)
            end 
          end 
        end

        context 'and defaultValue only' do
          before { runnable.script.variable.first.expression = nil }

          it 'returns replaced default input' do
            expect(runnable.replace_variables(input)).to eq(default_output)
          end 
        end 

        context 'and no defaultValue' do
          before { runnable.script.variable.first.defaultValue = nil }

          it 'returns the input' do
            expect(runnable.replace_variables(input)).to eq(input)
          end 
        end
      end 
    end

    context 'given > 1 placeholders' do
      before do
        allow(runnable).to receive(:evaluate_expression).with(vexp, nil).and_return(vreplacement)
        allow(runnable).to receive(:evaluate_expression).with(vexp1, nil).and_return(vreplacement1)
        allow(runnable).to receive(:evaluate_expression).with(vexp2, nil).and_return(vreplacement2)
      end 

      context 'without matches' do
        before { runnable.script.variable = [] }

        it 'returns input' do
          expect(runnable.replace_variables(multi_place_input)).to eq("/${#{vname}}/${#{vname1}}/${#{vname2}}")
        end 
      end 

      context 'with some matches' do
        before { runnable.script.variable.pop }

        context 'that all resolve' do
          it 'returns semi-replaced input' do
            expect(runnable.replace_variables(multi_place_input)).to eq("/#{vreplacement}/#{vreplacement1}/${#{vname2}}")
          end 
        end

        context 'that do not all resolve' do
          before { allow(runnable).to receive(:evaluate_expression).with(vexp1, nil).and_return(nil) }

          context 'but do have defaultValue' do
            it 'returns semi-replaced input, with a default' do
              expect(runnable.replace_variables(multi_place_input)).to eq("/#{vreplacement}/#{vdefault1}/${#{vname2}}")
            end 
          end 

          context 'and do not have defaultValue' do
            before { runnable.script.variable[1].defaultValue = nil }

            it 'returns semi-replaced input, without a default' do
              expect(runnable.replace_variables(multi_place_input)).to eq("/#{vreplacement}/${#{vname1}}/${#{vname2}}")
            end 
          end 
        end

        context 'that do not resolve' do
          before do
            allow(runnable).to receive(:evaluate_expression).with(vexp, nil).and_return(nil)
            allow(runnable).to receive(:evaluate_expression).with(vexp1, nil).and_return(nil)
          end

          context 'but do have defaultValue' do
            it 'returns semi-replaced input, with only defaults' do
              expect(runnable.replace_variables(multi_place_input)).to eq("/#{vdefault}/#{vdefault1}/${#{vname2}}")
            end 
          end 

          context 'and do not have defaultValue' do
            before { runnable.script.variable.each { |var| var.defaultValue = nil } }

            it 'returns input' do
              expect(runnable.replace_variables(multi_place_input)).to eq("/${#{vname}}/${#{vname1}}/${#{vname2}}")
            end 
          end 
        end 
      end 

      context 'with matches' do
        context 'that all resolve' do
          it 'returns replaced input' do
            expect(runnable.replace_variables(multi_place_input)).to eq("/#{vreplacement}/#{vreplacement1}/#{vreplacement2}")
          end 
        end
        
        context 'that do not all resolve' do
          before { allow(runnable).to receive(:evaluate_expression).with(vexp1, nil).and_return(nil) }
         
          context 'but do have defaultValue' do
            it 'returns fully replaced input, with a default' do
              expect(runnable.replace_variables(multi_place_input)).to eq("/#{vreplacement}/#{vdefault1}/#{vreplacement2}")
            end 
          end 

          context 'and do not have defaultValue' do
            before { runnable.script.variable[1].defaultValue = nil }

            it 'returns semi-replaced input, without a default' do
              expect(runnable.replace_variables(multi_place_input)).to eq("/#{vreplacement}/${#{vname1}}/#{vreplacement2}")
            end 
          end 
        end

        context 'that all do not resolve' do
          before do 
            allow(runnable).to receive(:evaluate_expression).with(vexp, nil).and_return(nil)
            allow(runnable).to receive(:evaluate_expression).with(vexp1, nil).and_return(nil)
            allow(runnable).to receive(:evaluate_expression).with(vexp2, nil).and_return(nil)
          end

          context 'but do have defaultValue' do
            it 'returns fully replaced input, with only defaults' do
              expect(runnable.replace_variables(multi_place_input)).to eq("/#{vdefault}/#{vdefault1}/#{vdefault2}")
            end 
          end 

          context 'and do not have defaultValue' do
            before { runnable.script.variable.each { |var| var.defaultValue = nil } }

            it 'returns input' do
              expect(runnable.replace_variables(multi_place_input)).to eq("/${#{vname}}/${#{vname1}}/${#{vname2}}")
            end 
          end 
        end 
      end 

      context 'with a var matching > 1 placeholder' do
        context 'that resolves' do
          it 'returns fully replaced input' do
            expect(runnable.replace_variables(multi_match_input)).to eq("/#{vreplacement}/#{vreplacement}")
          end 
        end

        context 'that does not resolve' do
          before { allow(runnable).to receive(:evaluate_expression).with(vexp, nil).and_return(nil) }

          context 'but does have defaultValue' do
            it 'returns fully replaced input, with only defaults' do
              expect(runnable.replace_variables(multi_match_input)).to eq("/#{vdefault}/#{vdefault}")
            end 
          end

          context 'and does not have defaultValue' do
            before { runnable.script.variable[0].defaultValue = nil }

            it 'returns input' do
              expect(runnable.replace_variables(multi_match_input)).to eq("/${#{vname}}/${#{vname}}")
            end 
          end 
        end 
      end 
    end 
  end 
end
