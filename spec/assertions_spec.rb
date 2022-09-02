require 'Assertions'
require 'fhir_models'

class AssertionTestClass
  include Assertions
end

describe Assertions do
  describe '.evaluate' do
    # TODO
  end

  describe '.determine_assert_type' do
    before(:each) do
      @assert = FHIR::TestScript::Setup::Action::Assert.new
    end
    before(:all) do
      @tester = AssertionTestClass.new
    end

    it 'calls content_type, if assert had contentType element' do
      @assert.contentType = 'contentType'
      @assert

      expect(determine_assert_type())
    end

    # it 'calls expression, if assert has expression element' do
    #   @assert.expression = 'expression'
    # end

    # it 'calls header_field, if assert has headerField element' do
    # end

    # it 'calls minimum_id, if assert has minimumId element' do
    # end
  end
end