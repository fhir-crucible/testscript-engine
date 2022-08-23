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
endpoints = []
directory_path = '../TestScripts'
file_name = nil

parameters = ARGV
parameters.each do |parameter|
  if parameter.include?('.json') || parameter.include?('.xml')
    file_name = parameter
>>>>>>> c6f4de8 (Added multi-destination features, example testscript)
  elsif parameter.include?('http')
    endpoints << parameter
  else
    directory_path = parameter
  end
end

endpoints = ['https://server.fire.ly/'] if endpoints.length == 0

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