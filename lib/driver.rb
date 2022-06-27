require 'pry-nav' # TODO: Remove
require_relative './TestScriptEngine'
require './TestScriptRunnable' # TODO: Remove

test_server_url = 'http://hapi.fhir.org/baseR4'
testscript_path = nil

parameters = ARGV
parameters.each do |parameter|
  if parameter.start_with?('http')
    test_server_url = parameter
  else
    testscript_path = parameter
  end
end

puts "SERVER: #{test_server_url}"
puts "TESTSCRIPTS: #{testscript_path}"

default_engine = TestScriptEngine.new(test_server_url, testscript_path)
# Load and execute all TestScript in /TestScripts
default_engine.load_scripts
# Specify a TestScript to execute
# default_engine.load_scripts(nil, 'general_test_script.json')
default_engine.make_runnables
default_engine.execute_runnables
default_engine.write_reports

#default_engine.generate_runnables
# default_engine.execute(FHIR::Client.new('http://hapi.fhir.org/baseR4'))