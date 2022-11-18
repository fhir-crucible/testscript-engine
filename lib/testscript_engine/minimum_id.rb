require 'json'

def check_minimum_id(spec, actual)
    
    if spec.is_a?(Hash) && actual.is_a?(Hash)
        return !check_minimum_id_hash(spec, actual)
    end

    if spec.is_a?(Array) && actual.is_a?(Array)
        return !check_minimum_id_array(spec, actual)
    end

    return spec == actual
end

def check_minimum_id_hash(spec, actual)
    err_flg = false

    spec.each do |k, v|
        err_flg = true unless check_minimum_id(spec[k], actual[k]) 
    end

    return err_flg
end

def check_minimum_id_array(spec, actual)
    err_flg = false

    spec.each do |_spec|
        found_flg = false
        
        actual.each do |_actual|
            if check_minimum_id(_spec, _actual)
                actual.delete(_actual) 
                found_flg = true
                break
            end
        end

        err_flg = true unless found_flg
    end

    return err_flg
end