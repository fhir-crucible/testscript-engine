require 'pry-nav' # TODO: Remove
require 'fhir_client'
require_relative 'testscript_runnable'
require_relative 'message_handler'

class TestScriptEngine
  prepend MessageHandler

  attr_accessor :endpoint, :directory_path, :file_name

  def scripts
    @scripts ||= {}
  end

  def runnables
    @runnables ||= {}
  end

  def reports
    @reports ||= {}
  end

  def root
    directory_path || "../TestScripts"
  end

  def client
    @client ||= begin
      info(:begin_initialize_client)
      client = FHIR::Client.new(endpoint || 'localhost:3000')
      info(:finish_initialize_client)
      client
    end
  end

  def initialize(endpoint = nil, directory_path = nil, file_name = nil)
    self.endpoint = endpoint
    self.directory_path = directory_path
    self.file_name = file_name
    self.debug_mode = true
  end

  # TODO: Tie-in stronger validation. Possibly, Inferno validator.
  def valid_testscript? script
    return (script.is_a? FHIR::TestScript) && script.valid?
  end

  # @path [String] Optional, specifies the path to the folder containing the
  #                TestScript Resources to-be loaded into the engine.
  def load_scripts
    on_deck = Dir.glob (["#{root}/**/*.{json}", "#{root}/**/*.{xml}"])
    on_deck.each do |resource|
      next if resource.include? "/fixtures/"
      next if file_name && !resource.include?(file_name)

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
          error(:invalid_dump, script.validate.to_hash)
        end
      rescue
        info(:cant_deserialize_script, resource)
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
        info(:made_runnable, script.id)
      else
        scripts.each do |_, script|
          runnables[script.id] = TestScriptRunnable.new script
          info(:made_runnable, script.id)
        end
      end
    rescue => e
      error(:cant_make_runnable, script.id)
    end
  end

  # TODO: Clean-up, possibly modularize into a pretty_print type method
  # @runnable_id [String] Optional, specifies the id of the runnable to be
  #                       tested against the endpoint.
  def execute_runnables runnable_id = nil
    if runnable_id
      if runnables[runnable_id]
        reports[runnable_id] = runnable.run client
      else
        error(:no_runnable_stored, runnable_id)
      end
    else
      runnables.each do |id, runnable|
        reports[id] = runnable.run client
      end
    end
  end

  # @path [String] Optional, specifies the path to the folder which the
  #                TestReport resources should be written to.
  def write_reports path = nil
    report_directory = path || "#{root.split('/')[0...-1].join}/TestReports"
    FileUtils.mkdir_p report_directory

    reports.each do |_, report|
      File.open("#{report_directory}/#{report.name.downcase.split(' ')[1...].join('_')}.json", 'w') do |f|
        f.write(report.to_json)
      end
    end
  end
end