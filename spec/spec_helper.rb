# frozen_string_literal: true

require 'webmock/rspec'
require 'fhir_client'
require 'pry-nav'
WebMock.enable!

RSpec.configure do |config|
  config.before(:all) do
    #FHIR.logger = Logger.new('/dev/null')
    FHIR.logger = Logger.new(STDOUT)
    $stdout = File.open(File::NULL, "w")
  end
end