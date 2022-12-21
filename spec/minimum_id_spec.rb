require_relative '../lib/testscript_engine/assertion'
require 'fhir_models'

class AssertionTestClass
    include Assertion
    attr_accessor :response_map, :request_map, :fixtures, :reply
  end
  
  describe Assertion do
    before(:each) do
        @tester = AssertionTestClass.new

        @pt_compare = JSON.parse(File.read('./spec/fixtures/example_patient.json'))
        @pt_minimum = JSON.parse(File.read('./spec/fixtures/example_patient_min.json'))
        @pt_name_compare = JSON.parse(File.read('./spec/fixtures/patient_just_name.json'))
        @pt_name_minimum = JSON.parse(File.read('./spec/fixtures/patient_just_name_min.json'))
        @pt_twoNames_compare_jumbled = JSON.parse(File.read('./spec/fixtures/patient_two_names_jumbled.json'))
        @pt_twoNames_compare_jumbled_more = JSON.parse(File.read('./spec/fixtures/patient_two_names_jumbled_more.json'))
        @pt_twoNames_minimum = JSON.parse(File.read('./spec/fixtures/patient_two_names_min.json'))
        @pt_duplicateNames_compare_onlyOne = JSON.parse(File.read('./spec/fixtures/patient_duplicate_names_only_one.json'))
        @pt_duplicateNames_minimum = JSON.parse(File.read('./spec/fixtures/patient_duplicate_names_min.json'))
        @mCODE_cs_compare = JSON.parse(File.read('./spec/fixtures/mCODE_CapabilityStatement_exampleServer.json'))
        @mCODE_cs_compare_fail = JSON.parse(File.read('./spec/fixtures/mCODE_CapabilityStatement_exampleServer_shouldFail.json'))
        @mCODE_cs_minimum = JSON.parse(File.read('./spec/fixtures/mCODE_CapabilityStatement_ConditionSearch.json'))
        @pt_simple_min = JSON.parse(File.read('./spec/fixtures/patient_simple_min.json'))
        @pt_simple_okay = JSON.parse(File.read('./spec/fixtures/patient_simple_okay.json')) 
        @pt_simple_okay_jumbled = JSON.parse(File.read('./spec/fixtures/patient_simple_okay_jumbled.json')) 
        @pt_simple_wrongGender = JSON.parse(File.read('./spec/fixtures/patient_simple_wrongGender.json')) 
    end
  
    describe 'to examine minimum of the other' do

        context 'with pt_minimum, pt_compare' do
            it 'returns true' do
                errors = []
                expect(@tester.check_minimum_id(@pt_minimum, @pt_compare, "", errors)).to be(true)
                expect(errors.count).to eq(0)
            end
        end

        context 'with pt_name_minimum, pt_name_compare' do
            it 'returns true' do
                errors = []
                expect(@tester.check_minimum_id(@pt_name_minimum, @pt_name_compare, "", errors)).to be(true)
                expect(errors.count).to eq(0)
            end
        end

        context 'with pt_twoNames_minimum, pt_twoNames_compare_jumbled' do
            it 'returns false' do
                errors = []
                expect(@tester.check_minimum_id(@pt_twoNames_minimum, @pt_twoNames_compare_jumbled, "", errors)).to be(false)
                expect(errors.count).to eq(2)
                expect(errors[0]).to eq("name[0]")
                expect(errors[1]).to eq("name[1]")
            end
        end

        context 'with pt_twoNames_minimum, pt_twoNames_compare_jumbled_more' do
            it 'returns false' do
                errors = []
                expect(@tester.check_minimum_id(@pt_twoNames_minimum, @pt_twoNames_compare_jumbled_more, "", errors)).to be(false)
                expect(errors.count).to eq(1)
                expect(errors[0]).to eq("name[1]")
            end
        end

        context 'with pt_duplicateNames_minimum, pt_duplicateNames_compare_onlyOne' do
            it 'returns false' do
                errors = []
                expect(@tester.check_minimum_id(@pt_duplicateNames_minimum, @pt_duplicateNames_compare_onlyOne, "", errors)).to be(false)
                expect(errors.count).to eq(1)
                expect(errors[0]).to eq("name[1]")
            end
        end

        context 'with mCODE_cs_minimum, mCODE_cs_compare' do
            it 'returns true' do
                errors = []
                expect(@tester.check_minimum_id(@mCODE_cs_minimum, @mCODE_cs_compare, "", errors)).to be(true)
                expect(errors.count).to eq(0)
            end
        end

        context 'with mCODE_cs_minimum, mCODE_cs_compare_fail' do
            it 'returns false' do
                errors = []
                expect(@tester.check_minimum_id(@mCODE_cs_minimum, @mCODE_cs_compare_fail, "", errors)).to be(false)
                expect(errors.count).to eq(1)
                expect(errors[0]).to eq("rest[0]")
            end
        end

        context 'with pt_simple_min, pt_simple_okay' do
            it 'returns false' do
                errors = []
                expect(@tester.check_minimum_id(@pt_simple_min, @pt_simple_okay, "", errors)).to be(true)
                expect(errors.count).to eq(0)
            end
        end

        context 'with pt_simple_min, pt_simple_okay_jumbled' do
            it 'returns false' do
                errors = []
                expect(@tester.check_minimum_id(@pt_simple_min, @pt_simple_okay_jumbled, "", errors)).to be(true)
                expect(errors.count).to eq(0)
            end
        end

        context 'with pt_simple_min, pt_simple_wrongGender' do
            it 'returns false' do
                errors = []
                expect(@tester.check_minimum_id(@pt_simple_min, @pt_simple_wrongGender, "", errors)).to be(false)
                expect(errors.count).to eq(1)
                expect(errors[0]).to eq("gender")
            end
        end
    end
  end