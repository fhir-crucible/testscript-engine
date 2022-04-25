# frozen_string_literal: true
require 'TestScriptRunnable'

describe TestScriptRunnable do
  let(:endpoint) { 'https://dummy_endpoint.com' }
  let(:not_endpoint) { 'https://not_dummy_endpoint.com' }
  let(:content_type) { 'application/fhir+text/html' }
  let(:not_content_type) { 'text/html; charset=UTF-8' }
  let(:response_code) { "200,204" }
  let(:expected_response) { "okay" }
  let(:patient_input) { { "name" => [FHIR::HumanName.new({ 'family' => 'Chalmers', 'given' => ["Peter"] })] } }
  let(:patient) { FHIR::Patient.new(patient_input) }
  let(:source_expression) { "Patient.name.first().family" }
  let(:source_id) { '$some_id' }
  let(:headers) { { 'content-type' => content_type, "accept-charset" => "utf-8" } }
  let(:request) do 
    {
      :method => :get,
      :url => endpoint,
      :path => 'Patient/123/$everything',
      :headers => {},
      :payload => nil
    }
  end 
  let(:response) do
    {
      :code => 200,
      :headers => headers,
      :body => patient.to_json
    } 
  end 
  let(:client) { FHIR::Client.new(endpoint) }
  let(:client_reply_input) { [request, response, client] }
  let(:client_reply) { FHIR::ClientReply.new(*client_reply_input) }
  let(:assertion) { FHIR::TestScript::Setup::Action::Assert.new }
  let(:tScript) { FHIR::TestScript.new }
  let(:runnable) { TestScriptRunnable.new(tScript) }
  before do
    runnable.fixtures[source_id] = patient
    client_reply.resource = FHIR.from_contents(patient.to_json)
  end 

  describe '#handle_assertion' do
    context 'when given a non-assert object' do
      it 'returns a fail report' do
        result = runnable.handle_assertion(nil)

        expect(result).to eq(runnable.fail_report('invalidAssert'))
      end 
    end

    context 'when given an assert' do
      context 'with requestURL set' do
        before do
          assertion.requestURL = endpoint
          assertion.operator = "equals"
        end 

        context 'with no reply' do
          it 'returns an error report' do
            result = runnable.handle_assertion(assertion)
            expect(result.result).to eq('error')
          end 
        end

        context 'with a reply' do
          before { runnable.last_reply = client_reply }

          context 'with the a non-matching previously queried url' do  
            before { runnable.last_reply.request[:url] = not_endpoint } 

            it 'returns a fail report' do
              result = runnable.handle_assertion(assertion)
              expect(result.result).to eq('fail')
              expect(result.message).to eq("[.assert_request_url] Expected #{endpoint} but found #{not_endpoint}.")
            end 
          end
          
          context 'with a matching previously queried url' do  
            it 'returns a pass report' do 
              result = runnable.handle_assertion(assertion)
              expect(result.result).to eq('pass')
            end 
          end 
        end 
      end 

      context 'with contentType set' do
        before { assertion.contentType = content_type }

        context 'with no reply' do
          it 'returns an error report' do
            result = runnable.handle_assertion(assertion)
            expect(result.result).to eq('error')
          end 
        end

        context 'with a reply' do
          before { runnable.last_reply = client_reply }

          context 'with the no content-type header' do  
            before { runnable.last_reply.response[:headers]['content-type'] = nil } 

            it 'returns a fail report' do
              result = runnable.handle_assertion(assertion)
              expect(result.result).to eq('fail')
              expect(result.message).to eq("[.assert_content_type] Expected content-type header not included in response.")
            end 
          end

          context 'with the a non-matching content-type header' do  
            before { runnable.last_reply.response[:headers]['content-type'] = not_content_type } 

            it 'returns a fail report' do
              result = runnable.handle_assertion(assertion)
              expect(result.result).to eq('fail')
              expect(result.message).to eq("[.assert_content_type] Expected content-type with value: application/fhir+text/html, but found value: text/html; charset=UTF-8.")
            end 
          end
          
          context 'with a matching previously queried url' do  
            it 'returns a pass report' do 
              result = runnable.handle_assertion(assertion)
              expect(result.result).to eq('pass')
            end 
          end 
        end 
      end 

      # context 'with compareToSourceExpression set' do
      #   before do 
      #     assertion.compareToSourceExpression = source_expression 
      #     assertion.compareToSourceId = source_id
      #   end 

      #   context 'with no reply' do
      #     it 'returns an error report' do
      #       result = runnable.handle_assertion(assertion)
      #       expect(result.result).to eq('error')
      #     end 
      #   end

      #   context 'with a reply' do
      #     before { runnable.last_reply = client_reply }

      #     context 'with no fixture correlating to Source Id' do
      #       before { runnable.fixtures[source_id] = nil }

      #       it 'returns a fail report' do
      #         result = runnable.handle_assertion(assertion)
      #         expect(result.result).to eq('fail')
      #         expect(result.message).to eq("[.assert_compare_to_source_expression] Expected fixture with id #{source_id} not found.")
      #       end
      #     end 

      #     context 'with a mismatched resource' do  
      #       before { runnable.last_reply.resource = FHIR::Patient.new } 

      #       it 'returns a fail report' do
      #         result = runnable.handle_assertion(assertion)
      #         expect(result.result).to eq('fail')
      #         expect(result.message).to eq('[.assert_compare_to_source_expression] Expected Chalmers but found ')
      #       end 
      #     end

      #     context 'with unexpected matched resources' do
      #       before { assertion.operator = 'notEquals' }

      #       it 'returns a fail report' do
      #         result = runnable.handle_assertion(assertion)
      #         expect(result.result).to eq('fail')
      #         expect(result.message).to eq("[.assert_compare_to_source_expression] Did not expect Chalmers but found Chalmers.")
      #       end 
      #     end
          
      #     context 'with a matching previously queried url' do  
      #       it 'returns a pass report' do 
      #         result = runnable.handle_assertion(assertion)
      #         expect(result.result).to eq('pass')
      #       end 
      #     end 
      #   end 
      # end 

      context 'with headerField set' do
        before do
          assertion.headerField = 'Accept-Charset'
          assertion.value = 'utf-8'
        end 

        context 'with no reply' do
          it 'returns an error report' do
            result = runnable.handle_assertion(assertion)
            expect(result.result).to eq('error')
          end 
        end

        context 'with a reply' do
          before { runnable.last_reply = client_reply }

          context 'with no matching headers in request' do
            before do
              assertion.headerField = 'User-Agent'
              assertion.value = 'Ruby FHIR Client'
              assertion.direction = 'request'
            end 

            it 'returns a fail report' do
              result = runnable.handle_assertion(assertion)
              expect(result.result).to eq('fail')
              expect(result.message).to eq("[.assert_header_field] Request Header Field User-Agent -- Expected Ruby FHIR Client but found nothing.")
            end
          end 

          context 'with a mismatched header value in request' do  
            before do
              assertion.headerField = 'Accept-Charset'
              assertion.value = 'UTF-9'
            end 

            it 'returns a fail report' do
              result = runnable.handle_assertion(assertion)
              expect(result.result).to eq('fail')
              expect(result.message).to eq('[.assert_header_field] Response Header Field Accept-Charset -- Expected UTF-9 but found utf-8.')
            end 
          end

          context 'with unexpected matched resources' do
            before { assertion.operator = 'notEquals' }

            it 'returns a fail report' do
              result = runnable.handle_assertion(assertion)
              expect(result.result).to eq('fail')
              expect(result.message).to eq('[.assert_header_field] Response Header Field Accept-Charset -- Did not expect utf-8 but found utf-8.')
            end 
          end
          
          context 'with a matching previously queried url' do  
            it 'returns a pass report' do 
              result = runnable.handle_assertion(assertion)
              expect(result.result).to eq('pass')
            end 
          end 
        end 
      end 

      context '#find_resource' do
        context 'with no resource stored anywhere' do
          it 'raises an AssertionException' do
            expect { runnable.find_resource('bad_id', 'spec_test') }.to raise_error(Assertions::AssertionException, 'spec_test Expected resource with id: bad_id in fixtures, responses, or in last reply from server. No such resource found.')
          end 
        end

        context 'with reply stored in response map' do
          before { runnable.response_map[source_id] = client_reply }

          it 'returns the resource returned in that reply' do
            result = runnable.find_resource(source_id, 'spec_test')
            expect(result).to eq(patient)
          end 
        end 

        context 'with resource stored in fixtures' do
          before { runnable.fixtures[source_id] = patient }

          it 'returns that resource' do
            result = runnable.find_resource(source_id, 'spec_test')
            expect(result).to eq(patient)
          end 
        end 

        context 'with resource stored in last_reply' do
          before { runnable.last_reply = client_reply }

          it 'returns the resource in that last reply' do
            result = runnable.find_resource(source_id, 'spec_test')
            expect(result).to eq(patient)
          end 
        end 
      end 

      context '#assert_resource' do
        before do
          assertion.resource = 'Patient'
          assertion.sourceId = source_id
          runnable.fixtures[source_id] = patient
        end 

        context 'with mismatch between resource class and assertion.resource' do
          before { assertion.resource = 'AllergyIntolerance' }

          it 'raises an AssertionException' do
            expect { runnable.assert_resource(assertion) }.to raise_error(Assertions::AssertionException, '[.assert_resource] Expected AllergyIntolerance but found Patient.')
          end 

          context 'with an notEquals operator' do
            before { assertion.operator = 'notEquals' }

            it 'returns nil' do
              result = runnable.assert_resource(assertion) 
              expect(result).to be(nil)
            end 
          end 
        end 

        context 'with a match between resource class and assertion.resource' do
          before { assertion.resource = 'Patient' }

          it 'returns nil' do
            result = runnable.assert_resource(assertion) 
            expect(result).to be(nil)
          end 

          context 'with an notEquals operator' do
            before { assertion.operator = 'notEquals' }

            it 'raises an AssertionException' do
              expect { runnable.assert_resource(assertion) }.to raise_error(Assertions::AssertionException, '[.assert_resource] Did not expect Patient but found Patient.')
            end 
          end 
        end 
      end 

      context '#assert_response_code' do
        before do
          runnable.response_map[source_id] = patient
          runnable.last_reply = client_reply
          assertion.responseCode = '200'
        end 

        context 'with no response in response map' do
          before { assertion.sourceId = 'empty_id' }

          it 'pulls response from last reply and returns nil' do
            result = runnable.assert_response_code(assertion)
          end 
        end 

        context 'with response in response map' do
          before { runnable.response_map[source_id] = client_reply }

          context 'with mismatch between last reply code and assertion.responseCode' do
            before { assertion.responseCode = '404' }
  
            it 'raises an AssertionException' do
              expect { runnable.assert_response_code(assertion) }.to raise_error(Assertions::AssertionException, '[.assert_response_code] Expected 404 but found 200.')
            end 
  
            context 'with an notEquals operator' do
              before { assertion.operator = 'notEquals' }
  
              it 'returns nil' do
                result = runnable.assert_response_code(assertion) 
                expect(result).to be(nil)
              end 
            end 
          end 
  
          context 'with a match between resource class and assertion.resource' do
            before { assertion.resource = '200' }
  
            it 'returns nil' do
              result = runnable.assert_response_code(assertion) 
              expect(result).to be(nil)
            end 
  
            context 'with an notEquals operator' do
              before { assertion.operator = 'notEquals' }
  
              it 'raises an AssertionException' do
                expect { runnable.assert_response_code(assertion) }.to raise_error(Assertions::AssertionException, '[.assert_response_code] Did not expect 200 but found 200.')
              end 
            end 
          end 
        end 
      end 

      context '#assert_response' do
        before do
          runnable.response_map[source_id] = patient
          runnable.last_reply = client_reply
          assertion.response = 'okay'
        end 

        context 'with no response in response map' do
          before { assertion.sourceId = 'empty_id' }

          it 'pulls response from last reply and returns nil' do
            result = runnable.assert_response(assertion)
          end 
        end 

        context 'with response in response map' do
          before { runnable.response_map[source_id] = client_reply }

          context 'with mismatch between last reply code and assertion.responseCode' do
            before { assertion.response = 'notFound' }
  
            it 'raises an AssertionException' do
              expect { runnable.assert_response(assertion) }.to raise_error(Assertions::AssertionException, '[.assert_response] Expected 404 but found 200.')
            end 
  
            context 'with an notEquals operator' do
              before { assertion.operator = 'notEquals' }
  
              it 'returns nil' do
                result = runnable.assert_response(assertion) 
                expect(result).to be(nil)
              end 
            end 
          end 
  
          context 'with a match between resource class and assertion.resource' do
            before { assertion.resource = 'okay' }
  
            it 'returns nil' do
              result = runnable.assert_response(assertion) 
              expect(result).to be(nil)
            end 
  
            context 'with an notEquals operator' do
              before { assertion.operator = 'notEquals' }
  
              it 'raises an AssertionException' do
                expect { runnable.assert_response(assertion) }.to raise_error(Assertions::AssertionException, '[.assert_response] Did not expect 200 but found 200.')
              end 
            end 
          end 
        end 
      end 

      context '#assert_request_method' do
        before do
          runnable.last_reply = client_reply
          assertion.requestMethod = 'get'
        end 

        before { runnable.response_map[source_id] = client_reply }

        context 'with mismatch between last reply request and assertion.requestMethod' do
          before { assertion.requestMethod = 'post' }

          it 'raises an AssertionException' do
            expect { runnable.assert_request_method(assertion) }.to raise_error(Assertions::AssertionException, '[.assert_request_method] Expected post but found get.')
          end 

          context 'with an notEquals operator' do
            before { assertion.operator = 'notEquals' }

            it 'returns nil' do
              result = runnable.assert_request_method(assertion) 
              expect(result).to be(nil)
            end 
          end 
        end 

        context 'with a match between last reply request and assertion.requestMethod' do
          it 'returns nil' do
            result = runnable.assert_request_method(assertion) 
            expect(result).to be(nil)
          end 

          context 'with an notEquals operator' do
            before { assertion.operator = 'notEquals' }

            it 'raises an AssertionException' do
              expect { runnable.assert_request_method(assertion) }.to raise_error(Assertions::AssertionException, '[.assert_request_method] Did not expect get but found get.')
            end 
          end 
        end 
      end

      context '#assert_path' do
        before do
          runnable.last_reply = client_reply
          assertion.path = '$.name[0].family'
          assertion.value = JsonPath.new(assertion.path).first(patient.to_json)
        end 

        context 'with assertion.value undefined' do
          before { assertion.value = nil }

          context 'with assertion.operator undefined' do
            it 'raises an AssertionException' do
              expect { runnable.assert_path(assertion) }.to raise_error(Assertions::AssertionException, '[.assert_path] Expected assertion.value to be defined. Assertion unprocessable without value.')
            end 
          end 

          context 'with assertion.operator equal to empty' do
            before { assertion.operator = 'empty' }

            it 'raises an AssertionException' do
              expect { runnable.assert_path(assertion) }.to raise_error(Assertions::AssertionException, '[.assert_path] Expected empty but found Chalmers.')
            end 
          end 

          context 'with assertion.operator equal to notEmpty' do
            before { assertion.operator = 'notEmpty' }

            it 'returns nil' do
              result = runnable.assert_path(assertion) 
              expect(result).to be(nil)
            end 
          end 
        end
      end 

      context '#assert_minimum_id' do
        before do
          assertion.minimumId = 'minimum_id'
          assertion.sourceId = source_id
          runnable.fixtures['minimum_id'] = patient
        end 

        context 'with resource in last reply not matching minimumId resource' do
          context 'by a degree of a hash key' do
            before do
              diff_resource = FHIR::AllergyIntolerance.new
              runnable.fixtures[source_id] = diff_resource
            end 

            it 'raises an AssertionException' do
              expect { runnable.assert_minimum_id(assertion) }.to raise_error(Assertions::AssertionException, '[.assert_minimum_id] Resource with id: $some_id does not have minimum content of resource with id: minimum_id.')
            end 
          end 

          context 'by a degree of a hash in an array' do
            before do
              diff_resource = FHIR::Patient.new
              runnable.fixtures[source_id] = diff_resource
            end 

            it 'raises an AssertionException' do
              expect { runnable.assert_minimum_id(assertion) }.to raise_error(Assertions::AssertionException, '[.assert_minimum_id] Resource with id: $some_id does not have minimum content of resource with id: minimum_id.')
            end 
          end 
        end 

        context 'with resource in last reply matching minimumId resource' do
          it 'returns nil' do
            result = runnable.assert_minimum_id(assertion) 
            expect(result).to be(nil)
          end 
        end 
      end 

      context '#assert_expression' do
        before do
          assertion.expression = "Patient.name[0].family = 'Chalmers'"
          runnable.last_reply = client_reply
        end 

        context 'with a FHIRPath expression that does not resolve' do
          before { assertion.expression = "Patient.name.onsetRange skdsmdksfd 'invalidExp'" }

          it 'raises an AssertionException' do
            expect { runnable.assert_expression(assertion) }.to raise_error(Assertions::AssertionException, "[.assert_expression] Expression: Patient.name.onsetRange skdsmdksfd 'invalidExp' did not evaluate to true for resource stored in latest reply from server. FHIRPath Expressions must evaluate to true.")
          end 
        end 

        context 'with a FHIRPath expression that resolves and evaluates to false' do
          before { assertion.expression = "Patient.name.family = 'notChalmers'" }

          it 'raises an AssertionException' do
            expect { runnable.assert_expression(assertion) }.to raise_error(Assertions::AssertionException, "[.assert_expression] Expression: Patient.name.family = 'notChalmers' did not evaluate to true for resource stored in latest reply from server. FHIRPath Expressions must evaluate to true.")
          end 
        end 

        context 'with a FHIRPath expression that resolves and evaluates to true' do
          it 'returns nil' do
            result = runnable.assert_expression(assertion) 
            expect(result).to be(nil)
          end 
        end 
      end 
    end 
  end 
end 