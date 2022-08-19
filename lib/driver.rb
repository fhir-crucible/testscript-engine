require_relative './TestScriptEngine'
require_relative './MessageHandler'

<<<<<<< HEAD
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
=======
endpoints = ['https://hapi.fhir.org/baseR4/', 'https://server.fire.ly/', 'https://api.logicahealth.org/TSEngineR4Endpoint1/open', 'https://api.logicahealth.org/TSEngineR4Endpoint2/open', 'https://api.logicahealth.org/TSEngineR4Endpoint3/open', 'https://api.logicahealth.org/TSEngineR4Endpoint4/open', 'https://api.logicahealth.org/TSEngineR4Endpoint5/open']
directory_path = '../TestScripts'
file_name = nil

parameters = ARGV
parameters.each do |parameter|
  if parameter.include?('.json') || parameter.include?('.xml')
    file_name = parameter
>>>>>>> c6f4de8 (Added multi-destination features, example testscript)
  else
    directory_path = parameter
  end
end

puts "SERVER: #{endpoints}"
puts "TESTSCRIPT PATH: #{directory_path}"
puts "TESTSCRIPT FILE: #{file_name}"

default_engine = TestScriptEngine.new(endpoints, directory_path, file_name)
default_engine.load_scripts
default_engine.make_runnables
default_engine.execute_runnables
default_engine.write_reports

#default_engine.generate_runnables
# default_engine.execute(FHIR::Client.new('http://hapi.fhir.org/baseR4'))