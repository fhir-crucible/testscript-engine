# frozen_string_literal: true

require 'pry-nav'
require 'fhir_client'
require_relative 'testscript_engine/testscript_runnable'
require_relative 'testscript_engine/output/message_handler'
require_relative 'testscript_engine/validation/validation'
require_relative 'testscript_engine/cli'

class TestScriptEngine
  prepend MessageHandler
  include Validation

  attr_accessor :endpoint, :input_path, :testreport_path, :nonfhir_fixture, :options

  def fixtures
    @fixtures ||= {}
  end

  def scripts
    @scripts ||= {}
  end

  def runnables
    @runnables ||= {}
  end

  def reports
    @reports ||= {}
  end

  def client
    @client ||= begin
      info(:begin_initialize_client)
      client = FHIR::Client.new(endpoint || 'localhost:3000')
      info(:finish_initialize_client)
      client
    end
  end

  def initialize(test_server_url, testscript_path, testreport_path, options)
    self.endpoint = test_server_url
    self.input_path = testscript_path
    self.testreport_path = testreport_path
    self.nonfhir_fixture = options[:nonfhir_fixture]
    self.options = options
    # self.debug_mode = true
  end

  # TODO: Tie-in stronger validation. Possibly, Inferno validator.
  def valid_testscript? script
    return (script.is_a? FHIR::TestScript) && valid_resource?(script)
  end

  # Load TestScripts and fixtures from the input_path
  def load_input
    input = Dir[input_path, "#{input_path}/**/*"].select { |f| File.file? f }

    input.each do |filename|
      fixture = filename.include?('/fixtures/')
      allow_non_fhir = fixture && nonfhir_fixture

      info(:loading_script, filename)
      increase_space
      begin
        contents = File.read(filename)
        resource = FHIR.from_contents(contents)
      rescue StandardError
      end

      next info(:illegible_file) unless contents
      next info(:non_fhir_contents) unless resource || allow_non_fhir

      if fixture
        input_name = filename.match(%r{fixtures/}).post_match
        fixtures[input_name] = resource || contents
        info(:loaded_fixture, input_name)
      else
        next info(:non_testscript) if resource.resourceType != 'TestScript'

        scripts[resource.name] = resource
        info(:loaded_script, resource.name)
      end
      decrease_space
      newline
    end
  end

  # @script [FHIR::TestScript] Optional, a singular TestScript resource to be
  #                            transformed into a runnable. If no resource is
  #                            given, all stored TestScript are by default
  #                            transformed into and stored as runnables.
  def make_runnables(script = nil)
    get_fixtures = ->(fixture_name) { fixtures[fixture_name] }
    if valid_testscript? script
      info(:creating_runnable, script.name)
      runnables[script.name] = TestScriptRunnable.new(script, get_fixtures, options)
    else
      scripts.each do |_name, script|
        info(:creating_runnable, script.name)
        runnables[script.name] = TestScriptRunnable.new(script, get_fixtures, options)
      end
    end
  rescue StandardError
    error(:unable_to_create_runnable, script.name)
  end

  # TODO: Clean-up, possibly modularize into a pretty_print type method
  # @runnable_name [String] Optional, specifies the id of the runnable to be
  #                       tested against the endpoint.
  def execute_runnables(runnable_name = nil)
    pass_results = []
    fail_results = []

    if runnable_name
      if runnables[runnable_name]
        report = runnables[runnable_name].run(client)
        if report.result == 'pass'
          pass_results << runnable_name
        else
          fail_results << [runnable_name, report.score, report.result]
        end
        reports[runnable_name] = report
      else
        error(:unable_to_locate_runnable, runnable_name)
      end
    else
      runnables.each do |name, runnable|
        report = runnable.run(client)
        if report.result == 'pass'
          pass_results << name
        else
          fail_results << [name, report.score, report.result]
        end
        reports[name] = report
      end
    end

    execution_results
    pass_execution_results(pass_results) unless pass_results.empty?
    fail_execution_results(fail_results) unless fail_results.empty?
    see_reports(testreport_path)
  end

  def verify_runnable(runnable_name)
    return true unless runnables[runnable_name].nil?

    false
  end

  def new_client(url)
    @client = nil
    @endpoint = url
  end

  # @path [String] Optional, specifies the path to the folder which the
  #                TestReport resources should be written to.
  def write_reports(path = nil)
    report_directory = path || testreport_path
    FileUtils.mkdir_p report_directory

    reports.each do |_, report|
      report_name = report.name.downcase.split(' ')[1...].join('_')
      report_name = report.name.downcase.split('_')[0...].join('_') if report_name == ''
      File.open("#{report_directory}/#{report_name}.json", 'w') do |f|
        f.write(report.to_json)
      end
    end
  end
end
