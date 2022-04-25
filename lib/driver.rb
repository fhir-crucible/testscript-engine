require 'pry-nav' # TODO: Remove
require_relative './TestScriptEngine'
require './TestScriptRunnable' # TODO: Remove

default_engine = TestScriptEngine.new 'http://hapi.fhir.org/baseR4'
default_engine.load_scripts
default_engine.make_runnables
default_engine.execute_runnables
default_engine.write_reports

#default_engine.generate_runnables
# default_engine.execute(FHIR::Client.new('http://hapi.fhir.org/baseR4'))