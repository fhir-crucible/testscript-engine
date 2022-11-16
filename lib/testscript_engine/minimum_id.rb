require 'json'

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
