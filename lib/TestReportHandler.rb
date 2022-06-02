# TODO: Refine naming
require 'fhir_client'
require_relative './MessageHandler.rb'

class TestReportHandler 
  attr_accessor :script

  def self.setup script 
    new.from_script script
  end 

  def actions array = nil
    @actions |= array if array
    @actions ||= []
  end 

  def report
    @report ||= FHIR::TestReport.new
  end 

  def section name = nil
    @section = "FHIR::TestReport::#{name}".constantize if name
    @section
  end 

  def initialize
    extend MessageHandler
  end 

  def from_script script
    unless (script.is_a? FHIR::TestScript) && script.valid?
      FHIR.logger.error '[.initialize] Received invalid or non-TestScript resource.'
      raise ArgumentError
    end 

    @report = ['setup', 'test', 'teardown'].each_with_object(boilerplate script) do |name, report|
      report.send("#{name}=", build_section(name, script.send(name)))
    end  

    auto_fixtures script 

    @num_tests = actions.length
    @num_failures = 0

    return self
  end 

  def build_section(name, section_script)
    return unless section_script
    section(name.capitalize)
    
    return section.new(action: build_action(section_script.action)) if name != 'test'
    section_script.map do |test|
      section.new({
        name: test.name,
        description: test.description,
        action: build_action(test.action)  
      })
    end  
  end 

  def build_action action_script
    return unless action_script

    action_klass = "#{section}::Action".constantize
    action_script.map do |action|
      type = action.operation ? 'operation' : 'assert'
      actions << action_klass.new
      actions.last.send("#{type}=", build_execution(action.send(type)))
      actions.last
    end
  end 

  def build_execution exec_script
    return unless exec_script

    execution = exec_script.class.to_s.sub('TestScript', 'TestReport').constantize
    return execution.new ({
      id: exec_script.label || exec_script.id,
      message: exec_script.description,
      result: FHIR::Coding.new({ 
        code: '', 
        system: 'http://hl7.org/fhir/ValueSet/report-action-result-codes' 
      })
    })
  end 

  def auto_fixtures script
    script.fixture.each do |fixture|
      actions.unshift build_action(build_create(fixture)) if fixture.autocreate
      actions << build_action(build_delete(fixture)) if fixture.autodelete
    end 
  end 

  def current_action message = nil
    action = actions.shift
    type = action.operation || action.assert
    type.message = message
    return type
  end 

  def fail message_type
    current_action(failure(message_type) || message_type).result.code = 'fail'
    @num_failures += 1
    return 
  end 

  def skip message_type
    current_action(skip(message_type) || message_type).result.code = 'skip'
    @num_tests -= 1
    return 
  end 

  def error message
    current_action(message).result.code = 'error'
    @num_failures += 1
    return
  end 

  def warning message
    current_action(message).result.code = 'warning'
    return
  end 

  def pass
    current_action.result.code = 'pass'
    return 
  end 

# Might need to alter ‘score’ calculation based on including/not including setup or teardown failures
# Or, add the option to decide whether to include them

  def finalize
    report.status = 'completed'
    report.score = ((1 - @num_failures / @num_tests.to_f) * 100).round(2)
    report.result = (report.score == 100 ? 'pass' : 'fail')
    report.issued = DateTime.now
    
    num_passes = 0
    report.test.each do |test| 
          test.action.each do |ac| 
              num_passes += 1 if ac.operation&.result&.code == 'pass'
              num_passes += 1 if ac.assert.result.code == 'pass' if ac.assert
          end 
    end 

    score_testonly = (num_passes / report.test[0].action.length.to_f * 100).round(2)

    return report
  end 

  def build_create fixture
    FHIR::TestScript::Setup::Action.new({
      id: "autocreated-#{fixture.id}",
      operation: FHIR::TestScript::Setup::Action::Operation.new({
        sourceId: fixture.id,
        local_method: 'post'
      })
    })
  end

  def build_delete fixture
    FHIR::TestScript::Teardown::Action.new({
      id: "autodeleted-#{fixture.id}",
      operation: FHIR::TestScript::Setup::Action::Operation.new({
        sourceId: fixture.id,
        local_method: 'delete'
      })
    })
  end

  def boilerplate script
    return FHIR::TestReport.new({ 
      score: 0.00,
      tester: 'The MITRE Corporation',
      name: script.name.gsub('TestScript', 'TestReport'),
      testScript: FHIR::Reference.new(reference: script.url),
      id: (script.id || script.url).gsub('TestScript', 'TestReport'),
      language: FHIR::Coding.new({ code: 'en', system: 'http://hl7.org/fhir/ValueSet/languages' }),
      status: FHIR::Coding.new({ code: 'waiting', system: 'http://hl7.org/fhir/report-status-codes' }),
      result: FHIR::Coding.new({ code: 'pending', system: 'http://hl7.org/fhir/ValueSet/report-result-codes' })
    }.merge! meta script)
  end 

  def meta script
    {
      versionId: '0',
      profile: ['https://www.hl7.org/fhir/testreport.html']
    }.merge! script.meta || {}
  end
end