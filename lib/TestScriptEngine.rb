require 'pry-nav' # TODO: Remove
require 'fhir_client'
require_relative './TestScriptRunnable'

class TestScriptEngine
  attr_accessor :endpoint, :directory_path

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
    @client ||= FHIR::Client.new(endpoint || 'localhost:3000') 
  end 

  def initialize(endpoint = nil, directory_path = nil)
    self.endpoint = endpoint
    self.directory_path = directory_path
  end

  # TODO: Tie-in stronger validation. Possibly, Inferno validator.
  def valid_testscript? script
    return (script.is_a? FHIR::TestScript) && script.valid?
  end 

  # @path [String] Optional, specifies the path to the folder containing the 
  #                TestScript Resources to-be loaded into the engine. 
  def load_scripts path = nil, file_name = nil
    on_deck = Dir.glob "#{path || root}/**.{json, xml}"
    FHIR.logger.info "[.load_scripts] TestScript Path: [#{path || root}]"

    on_deck.each do |resource|
      # next unless resource.include? file_name

      begin 
        script = FHIR.from_contents File.read(resource)
        if valid_testscript? script
          script.url = resource
          scripts[script.id] = script 
          FHIR.logger.info "[.load_scripts] TestScript with id [#{script.id}] loaded."
        else
          FHIR.logger.info "[.load_scripts] Invalid or non-TestScript detected. Skipping resource at #{resource}."
        end 
      rescue
        FHIR.logger.info "[.load_scripts] Unable to deserialize TestScript resource at #{resource}."
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
        FHIR.logger.info "[.make_runnables] Generated runnable from TestScript with id [#{script.id}]."
      else 
        scripts.each do |_, script|
          runnables[script.id] = TestScriptRunnable.new script
          FHIR.logger.info "[.make_runnables] Generated runnable from TestScript with id [#{script.id}]."
        end 
      end 
    rescue => e
      FHIR.logger.error "[.make_runnables] Unable to generate runnable. Caught error: #{e.message}."
    end 
  end 

  # TODO: Clean-up, possibly modularize into a pretty_print type method
  # @runnable_id [String] Optional, specifies the id of the runnable to be
  #                       tested against the endpoint.
  def execute_runnables runnable_id = nil
    if runnable_id
      if runnables[runnable_id]
        puts "\nBeggining execution of #{runnable_id}.\n\n"
        reports[runnable_id] = runnable.execute client 
        runnable.postprocess
        puts "\nFinished execution of #{runnable_id}. Score: #{reports[runnable_id].score} \n"
      else
         FHIR.logger.info "[.execute_runnables] No runnable stored with id [#{runnable_id}]." 
      end 
    else
      runnables.each do |id, runnable|
        puts "\nBeggining execution of #{id}.\n\n"
        reports[id] = runnable.run client
        puts "\nFinished execution of #{id}. Score: #{reports[id].score} \n"
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