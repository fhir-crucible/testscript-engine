require 'pry-nav'
require 'fhir_client'
require 'fhir_models'
require_relative 'testscript_engine/testscript_runnable'
require_relative 'testscript_engine/message_handler'

class TestScriptEngine
  prepend MessageHandler

  attr_accessor :endpoint, :testscript_path, :testreport_path

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

  def initialize(endpoint, testscript_path, testreport_path)
    self.endpoint = endpoint
    self.testscript_path = testscript_path
    self.testreport_path = testreport_path
    self.debug_mode = true
  end

  # TODO: Tie-in stronger validation. Possibly, Inferno validator.
  def valid_testscript? script
    return (script.is_a? FHIR::TestScript) && script.valid?
  end

  # @path [String] Optional, specifies the path to the folder containing the
  #                TestScript Resources to-be loaded into the engine.
  def load_scripts
		if File.file?(testscript_path)
			on_deck = [testscript_path]
		elsif File.directory?(testscript_path)
			on_deck = Dir.glob (["#{testscript_path}/**/*.{json}", "#{testscript_path}/**/*.{xml}"])
		end
    on_deck.each do |resource|
      next if resource.include? "/fixtures/"

      begin
        script = FHIR.from_contents File.read(resource)
        if valid_testscript? script
          script.url = resource
          if scripts[script.id]
            info(:overwrite_existing_script, script.id)
          else
            info(:loaded_script, script.id)
          end
          scripts[script.id] = script
        else
          info(:invalid_script, resource)
        end
      rescue
        info(:bad_serialized_script, resource)
      end
    end
  end

  # @script [FHIR::TestScript] Optional, a singular TestScript resource to be
  #                            transformed into a runnable. If no resource is
  #                            given, all stored TestScript are by default
  #                            transformed into and stored as runnables.
  def make_runnables script = nil
    begin
      if valid_testscript? script
        runnables[script.id] = TestScriptRunnable.new script
        info(:created_runnable, script.id)
      else
        scripts.each do |_, script|
          runnables[script.id] = TestScriptRunnable.new script
          info(:created_runnable, script.id)
        end
      end
    rescue => e
      error(:unable_to_create_runnable, script.id)
    end
  end

  # TODO: Clean-up, possibly modularize into a pretty_print type method
  # @runnable_id [String] Optional, specifies the id of the runnable to be
  #                       tested against the endpoint.
  def execute_runnables(runnable_id = nil)
    pass_results = []
    fail_results = []

    if runnable_id
      if runnables[runnable_id]
        report = runnables[runnable_id].run(client)
        if report.result == 'pass'
          pass_results << runnable_id
        else
          fail_results << [runnable_id, report.score, report.result]
        end
        reports[runnable_id] = report
      else
        error(:unable_to_locate_runnable, runnable_id)
      end
    else
      runnables.each do |id, runnable|
        report = runnable.run(client)
        if report.result == 'pass'
          pass_results << id
        else
          fail_results << [id, report.score, report.result]
        end
        reports[id] = report
      end
    end

    execution_results
    pass_execution_results(pass_results) unless pass_results.empty?
    fail_execution_results(fail_results) unless fail_results.empty?
    see_reports(testreport_path)
  end

	def verify_runnable(runnable_id)
		return true unless runnables[runnable_id].nil?
		false
	end

	def new_client(url)
		@client = nil
		@endpoint = url
	end

  # @path [String] Optional, specifies the path to the folder which the
  #                TestReport resources should be written to.
  def write_reports path = nil
    report_directory = path || testreport_path
    FileUtils.mkdir_p report_directory

    reports.each do |_, report|
      report_name = report.name.downcase.split(' ')[1...].join('_')
      report_name = report.name.downcase.split('_')[0...].join('_') if report_name == ""
      File.open("#{report_directory}/#{report_name}.json", 'w') do |f|
        f.write(report.to_json)
      end
    end
  end
end
