require './TestScriptEngine'

engine = TestScriptEngine.new('http://localhost:8080/fhir/')
engine.read_tScript_resources('../TestScripts')

# Testing the read_tScript_example TestScript 
engine.create_runnables(engine.tScripts[1])
engine.execute_tScripts
engine.write_tReport