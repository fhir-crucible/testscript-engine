# frozen_string_literal: true
Gem::Specification.new do |s|
  s.name = 'testscript_engine'
  s.version = '1.0.0'
  s.summary = 'An engine for loading and executing FHIR TestScript resources'
  s.author = ['John Fraser']
  s.email = 'jfraser@mitre.org'
  s.license = 'Apache-2.0'
  s.add_runtime_dependency 'activesupport'
  s.add_runtime_dependency 'fhir_client'
  s.add_runtime_dependency 'fhir_models'
  s.add_runtime_dependency 'jsonpath'
  s.add_development_dependency 'rspec', '~> 3.10'
  s.add_development_dependency 'webmock', '~> 3.10'
  s.required_ruby_version = Gem::Requirement.new('>= 2.7.0')
  s.files = [Dir['lib/**/*.rb']].flatten
  s.require_paths = ['lib']
  s.executables << "testscript_engine"
end