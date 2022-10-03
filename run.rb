cmd = `gem list -d 'fhir_client' | grep -E 'Installed at:\s+(.*)$' | cut -d ":" -f 2 | tr -d '[:space:]'`
$LOAD_PATH.unshift("#{cmd}/gems/fhir_client-5.0.3/lib") unless cmd.empty?

require_relative 'lib/testscript_engine'
TestScriptEngine::CLI.start