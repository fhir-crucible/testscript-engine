require_relative 'testscript_engine'
require_relative './MessageHandler'

include MessageHandler

test_server_url = "http://hapi.fhir.org/baseR4" #'http://server.fire.ly' # #
testscript_path = '../TestScripts'
testscript_file = nil

parameters = ARGV
parameters.each do |parameter|
  if parameter.start_with?('http')
    test_server_url = parameter
  elsif parameter.include?('.json') || parameter.include?('.xml')
    testscript_file = parameter
  else
    testscript_path = parameter
  end
end

puts "SERVER: #{test_server_url}"
puts "TESTSCRIPT PATH: #{testscript_path}"
puts "TESTSCRIPT FILE: #{testscript_file}"

default_engine = TestScriptEngine.new(test_server_url, testscript_path, testscript_file)
default_engine.load_scripts
default_engine.make_runnables
default_engine.execute_runnables
default_engine.write_reports

#default_engine.generate_runnables
# default_engine.execute(FHIR::Client.new('http://hapi.fhir.org/baseR4'))