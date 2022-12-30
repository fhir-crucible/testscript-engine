require_relative './TestScriptEngine'
require_relative './MessageHandler'

<<<<<<< HEAD
include MessageHandler

endpoints = []
directory_path = '../TestScripts'
file_name = nil

parameters = ARGV
parameters.each do |parameter|
  if parameter.include?('.json') || parameter.include?('.xml')
    file_name = parameter
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