# frozen_string_literal: true

require 'webmock/rspec'
require 'fhir_client'
require 'pry-nav'
WebMock.enable!

RSpec.configure do |config|
  config.before(:all) do
    #FHIR.logger = Logger.new('/dev/null')
    FHIR.logger = Logger.new(RUBY_PLATFORM != 'i386-mingw32' ? '/dev/null' : 'NUL')
    
    $stdout = File.open(File::NULL, "w")
  end
end