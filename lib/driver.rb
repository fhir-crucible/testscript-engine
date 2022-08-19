require 'pry-nav' # TODO: Remove
require_relative './TestScriptEngine'
require './TestScriptRunnable' # TODO: Remove

endpoints = ['https://hapi.fhir.org/baseR4/', 'https://server.fire.ly/', 'https://api.logicahealth.org/TSEngineR4Endpoint1/open', 'https://api.logicahealth.org/TSEngineR4Endpoint2/open', 'https://api.logicahealth.org/TSEngineR4Endpoint3/open', 'https://api.logicahealth.org/TSEngineR4Endpoint4/open', 'https://api.logicahealth.org/TSEngineR4Endpoint5/open']
directory_path = '../TestScripts'
file_name = nil

parameters = ARGV
parameters.each do |parameter|
  if parameter.include?('.json') || parameter.include?('.xml')
    file_name = parameter
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