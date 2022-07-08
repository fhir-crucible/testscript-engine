# frozen_string_literal: true

require 'webmock/rspec'
WebMock.enable!

RSpec.configure do |config|
  config.before do
    FHIR.logger = Logger.new('/dev/null')
  end
end