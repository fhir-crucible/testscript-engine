require 'json'

pt_compare = JSON.parse(File.read('./spec/fixtures/example_patient.json'))
pt_minimum = JSON.parse(File.read('./spec/fixtures/example_patient_min.json'))
pt_name_compare = JSON.parse(File.read('./spec/fixtures/patient_just_name.json'))
pt_name_minimum = JSON.parse(File.read('./spec/fixtures/patient_just_name_min.json'))
mCODE_cs_compare = JSON.parse(File.read('./spec/fixtures/mCODE_CapabilityStatement_exampleServer.json'))
mCODE_cs_compare_fail = JSON.parse(File.read('./spec/fixtures/mCODE_CapabilityStatement_exampleServer_shouldFail.json'))
mCODE_cs_minimum = JSON.parse(File.read('./spec/fixtures/mCODE_CapabilityStatement_ConditionSearch.json'))
@flg = false

def find_match(data, l, k_target, v_target, l_target)
    if data.is_a?(Hash) 
        data.each do |k, v|
            if v.is_a?(Hash) || v.is_a?(Array)
                find_match(v, l+1, k_target, v_target, l_target) 
            end
            @flg = true if (v_target == v && k_target == k && l_target == l)
        end
    end

    if data.is_a?(Array) 
        data.each do |d| 
            find_match(d, l+1, k_target, v_target, l_target)
        end
    end
end

def eval_min(min_obj, tar_obj, level)
    if min_obj.is_a?(Hash) 
        min_obj.each do |k, v|
            if v.is_a?(Hash) || v.is_a?(Array)
                eval_min(v, tar_obj, level+1) 
                next
            end
            @flg = false
            find_match(tar_obj, 0, k, v, level)
            puts("Match? #{k} #{v} #{level} #{@flg}")
        end
    end

    if min_obj.is_a?(Array) 
        min_obj.each do |d|
            eval_min(d, tar_obj, level+1)
        end
    end
end

eval_min(pt_minimum, pt_compare, 0)
puts @flg
eval_min(pt_name_minimum, pt_name_compare, 0)
puts @flg
eval_min(mCODE_cs_minimum, mCODE_cs_compare, 0)
puts @flg
eval_min(mCODE_cs_minimum, mCODE_cs_compare_fail, 0)
puts @flg