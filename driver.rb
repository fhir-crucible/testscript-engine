require 'pry-nav'
require_relative 'lib/testscript_engine'

@test_server_url = "http://hapi.fhir.org/baseR4"
@testscript_path = "TestScripts"
@testreport_path = "TestReports"

engine = TestScriptEngine.new(@test_server_url, @testscript_path, @testreport_path)
engine.load_scripts
