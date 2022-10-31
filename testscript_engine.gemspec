# frozen_string_literal: true
Gem::Specification.new do |s|
  s.name = 'testscript_engine'
  s.version = '0.0.1'
  s.summary = 'An engine for loading and executing FHIR TestScript resources'
  s.author = ['John Fraser']
  s.email = 'jfraser@mitre.org'
  s.license = 'Apache-2.0'
  s.homepage = 'https://github.com/fhir-crucible/testscript-engine'
  s.add_runtime_dependency 'activesupport', '~> 7.0.4'
  s.add_runtime_dependency 'fhir_client', '~> 5.0.3'
  s.add_runtime_dependency 'jsonpath', '~> 1.1.2'
  s.add_development_dependency 'rspec', '~> 3.10'
  s.add_development_dependency 'webmock', '~> 3.10'
  s.add_development_dependency 'pry-nav', '~> 1.0.0'
  s.required_ruby_version = Gem::Requirement.new('>= 2.7.0')
  s.files = [Dir['lib/**/*.rb']].flatten
  s.require_paths = ['lib']
  s.executables << "testscript_engine"
end