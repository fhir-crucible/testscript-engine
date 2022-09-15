# frozen_string_literal: true
Gem::Specification.new do |s|
  s.name = 'testscript_engine'
  s.version = '1.0.0'
  s.summary = 'An engine for loading and executing FHIR TestScript resources'
  s.author = ['John Fraser']
  s.email = 'jfraser@mitre.org'
  s.license = 'Apache-2.0'
  s.files = [Dir['lib/**/*.rb']].flatten
  s.require_paths = ['lib']
  s.executables << "testscript_engine"
end
