require 'pry-nav'
module Assertions

  class AssertionException < Exception
    attr_accessor :data
    def initialize(message, data=nil)
      super(message)
      FHIR.logger.error "AssertionException: #{message}"
      @data = data
    end 
  end 

  def assert_contentType(reply, contentType)
    header = reply.response[:headers]['content-type']
    header!.split(';')[0]

    unless "application/fhir+#{contentType}" == response_content_type
      raise AssertionException.new "Expected content-type application/fhir+#{content_type} 
        but found #{response_content_type}", response_content_type
    end 
  end 

  def assert_operator(actual, operator, expected, message = '', data = '')
    case operator
    when :equals
      unless actual == expected
        message += " Expected #{expected} but found #{actual}"
        raise AssertionException.new message, data
      end 
    when :notEquals
      unless actual != expected_code
        message += " Did not expect #{expected} but found #{actual}."
        raise AssertionException.new message, data
      end
    when :in
      unless expected.split(',').include?(actual)
        message += " Expected #{expected} but found #{actual}."
        raise AssertionException.new message, data
      end
    when :notIn
      unless !expected.split(',').include?(actual)
        message += " Did not expect #{expected} but found #{actual}."
        raise AssertionException.new message, data
      end
    when :greaterThan
      unless actual && expected && actual > expected
        message += " Expected greater than #{expected} but found #{actual}."
        raise AssertionException.new message, data
      end
    when :lessThan
      unless actual && expected && actual < expected
        message += " Expected greater than #{expected} but found #{actual}."
        raise AssertionException.new message, data
      end
    when :empty 
      unless actual.nil? || ctual.length == 0
        message += " Expected empty but found #{actual}."
        raise AssertionException.new message, data
      end
    when :notEmpty
      unless actual && actual.length > 0
        message += " Expected not empty but found #{actual}."
        raise AssertionException.new message, data
      end
    when :contains
      unless actual && actual.include?(expected)
        message += " Expected #{actual} to contain #{expected}."
        raise AssertionException.new message, data
      end
    when :notContains
      unless actual.nil? || !actual.include?(expected)
        message += " Expected #{actual} to not contain #{expected}."
        raise AssertionException.new message, data
      end
    else
      message += " Invalid test; unknown operator: #{operator}."
      raise AssertionExection.new message, data
    end
  end 

  def assert_minimum(reply, fixture)
    raise AssertionException.new 'MinimumId not yet implemented'
  end 

  def assert_navigation_links(reply)
    bundle = reply.resource
    unless bundle.first_link && bundle.last_link && bundle.next_link
      raise AssertionException.new "Expecting first, next and last link to be present"
    end
  end 

  def assert_resource_type(reply, resource_type)
    unless reply.resource && reply.resource.class == resource_type
      raise AssertionException.new "Bad response type: expected #{resource_type}, but found #{reply.resource.class}.", reply.body
    end 
  end
  
  def assert_response_code(reply, code)
    unless reply.code.to_s == code.to_s
      raise AssertionException.new "Bad response code: expected #{code}, but found #{reply.code}", reply.body
    end 
  end 

  def assert_valid_profile(response, klass)
    unless response[:code].to_s == "200"

      raise AssertionException.new "Server created a #{klass.name.demodulize} with the ID `_validate` rather than validate the resource." if response[:code].to_s == "201"

      raise AssertionException.new "Response code #{response[:code]} with no OperationOutcome provided"
    end 
  end 



end 