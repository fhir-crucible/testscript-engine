require_relative '../lib/testscript_engine/minimum_id'

describe 'minimum_id' do

    pt_compare = JSON.parse(File.read('./spec/fixtures/example_patient.json'))
    pt_minimum = JSON.parse(File.read('./spec/fixtures/example_patient_min.json'))
    pt_name_compare = JSON.parse(File.read('./spec/fixtures/patient_just_name.json'))
    pt_name_minimum = JSON.parse(File.read('./spec/fixtures/patient_just_name_min.json'))
    pt_twoNames_compare_jumbled = JSON.parse(File.read('./spec/fixtures/patient_two_names_jumbled.json'))
    pt_twoNames_minimum = JSON.parse(File.read('./spec/fixtures/patient_two_names_min.json'))
    mCODE_cs_compare = JSON.parse(File.read('./spec/fixtures/mCODE_CapabilityStatement_exampleServer.json'))
    mCODE_cs_compare_fail = JSON.parse(File.read('./spec/fixtures/mCODE_CapabilityStatement_exampleServer_shouldFail.json'))
    mCODE_cs_minimum = JSON.parse(File.read('./spec/fixtures/mCODE_CapabilityStatement_ConditionSearch.json'))

    describe 'use two FHIR resources to examine minimum of the other' do

        context 'with pt_minimum, pt_compare' do
            it 'returns false' do
                expect(exam_minimum(pt_minimum.flatten_with_path, pt_compare.flatten_with_path)).to be(false)
            end
        end
    
        context 'with pt_twoNames_minimum, pt_twoNames_compare_jumbled' do
            it 'returns false' do
                expect(exam_minimum(pt_twoNames_minimum.flatten_with_path, pt_twoNames_compare_jumbled.flatten_with_path)).to be(false)
            end
        end

        context 'with mCODE_cs_minimum, mCODE_cs_compare' do
            it 'returns false' do
                expect(exam_minimum(mCODE_cs_minimum.flatten_with_path, mCODE_cs_compare.flatten_with_path)).to be(false)
            end
        end

        context 'with mCODE_cs_minimum, mCODE_cs_compare_fail' do
            it 'returns false' do
                expect(exam_minimum(mCODE_cs_minimum.flatten_with_path, mCODE_cs_compare_fail.flatten_with_path)).to be(false)
            end
        end
    end

end
