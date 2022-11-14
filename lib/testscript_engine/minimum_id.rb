require 'json'

pt_compare = JSON.parse(File.read('./spec/fixtures/example_patient.json'))
pt_minimum = JSON.parse(File.read('./spec/fixtures/example_patient_min.json'))
pt_name_compare = JSON.parse(File.read('./spec/fixtures/patient_just_name.json'))
pt_name_minimum = JSON.parse(File.read('./spec/fixtures/patient_just_name_min.json'))
pt_twoNames_compare_jumbled = JSON.parse(File.read('./spec/fixtures/patient_two_names_jumbled.json'))
pt_twoNames_minimum = JSON.parse(File.read('./spec/fixtures/patient_two_names_min.json'))
mCODE_cs_compare = JSON.parse(File.read('./spec/fixtures/mCODE_CapabilityStatement_exampleServer.json'))
mCODE_cs_compare_fail = JSON.parse(File.read('./spec/fixtures/mCODE_CapabilityStatement_exampleServer_shouldFail.json'))
mCODE_cs_minimum = JSON.parse(File.read('./spec/fixtures/mCODE_CapabilityStatement_ConditionSearch.json'))

module Enumerable
    def flatten_with_path(parent_prefix = nil)
        res = {}
  
        self.each_with_index do |elem, i|
            if elem.is_a?(Array)
                k, v = elem
            else
                k, v = 0, elem # change v = i to make order-aware
            end

            key = parent_prefix ? "#{parent_prefix}.#{k}" : k
    
            if v.is_a? Enumerable
                res.merge!(v.flatten_with_path(key)) 
            else
                res[key] = v
            end
        end
        res
    end
end

def exam_minimum(min, target)
    min.each do |k, v|
        return false if target[k] != v
    end
    return true
end

puts exam_minimum(pt_minimum.flatten_with_path, pt_compare.flatten_with_path)
puts exam_minimum(pt_twoNames_minimum.flatten_with_path, pt_twoNames_compare_jumbled.flatten_with_path)
puts exam_minimum(mCODE_cs_minimum.flatten_with_path, mCODE_cs_compare.flatten_with_path)
puts exam_minimum(mCODE_cs_minimum.flatten_with_path, mCODE_cs_compare_fail.flatten_with_path)