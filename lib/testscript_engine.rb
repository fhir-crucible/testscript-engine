# frozen_string_literal: true

require 'pry-nav'
require 'fhir_client'
require "csv"
require_relative 'testscript_engine/testscript_runnable'
require_relative 'testscript_engine/message_handler'
require_relative 'testscript_engine/validation'
require_relative 'testscript_engine/cli'

class TestScriptEngine
  prepend MessageHandler
  include Validation

  attr_accessor :endpoint, :input_path, :testreport_path, :nonfhir_fixture, :options, :variable, :client_util

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

  def profiles
    @profiles ||= {}
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
    self.nonfhir_fixture = options["nonfhir_fixture"]
    self.variable = options["variable"]
    self.options = options
    self.client_util = FHIR::Client.new('')
    load_profiles
  end

  def valid_testscript? script
    return (script.is_a? FHIR::TestScript) && valid_resource?(script, options)
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

  def load_profiles
    print_out " Loading profiles..."
    if options.key?("profile")
      options["profile"].each do |profile_location|
        print_out "  Loading profile from '#{profile_location}'"
        if profile_location.start_with? 'http'
          response = client_util.send(:get, profile_location, { 'Content-Type' => 'json' })
          if !response.response[:code].to_s.starts_with?('2')
            print_out "  -> Failed to load profile StructureDefinition from '#{profile_location}': Response code #{response.response[:code]}"
            raise "profile load failed"
          end
          profile_def = FHIR.from_contents(response.response[:body].to_s)
          profiles[profile_def.url] = profile_def
          info(:loaded_remote_profile, profile_def.url, profile_location)
        else
          profile_filepath = File.join(Dir.getwd, profile_location)
          if (File.directory?(profile_filepath))
            profiles_file_list = Dir["#{profile_filepath}/*"].select { |f| File.file? f }
            profiles_file_list.each do |filename|
              profile_def = FHIR.from_contents(File.read(filename))
              profiles[profile_def.url] = profile_def
              info(:loaded_local_profile, profile_def.url, filename)
            end
          else
            profile_def = FHIR.from_contents(File.read(profile_filepath))
            profiles[profile_def.url] = profile_def
            info(:loaded_local_profile, profile_def.url, profile_filepath)
          end
        end

        if options["ext_validator"] != nil 
          
        end
      end
    end
      
    if options["ext_validator"] != nil 
      # add any profiles loaded to the external validator
      profiles.each do |profile_url, profile_def|
        # load profile into external validator
        print_out  "  Adding '#{profile_url}' to external validator"
        reply = client_util.send(:post, options["ext_validator"]+"/profiles", profile_def, { 'Content-Type' => 'json' })

        if reply.response[:code].start_with?("2")
          print_out  "  -> Success! Added '#{profile_url}' to External validator."
        else
          raise "validator profile load failed"
        end
      end
      
      # add any profiles already available on this validator to the list
      reply = client_util.send(:get, options["ext_validator"]+"/profiles", { 'Content-Type' => 'json' })
      profiles_received = JSON.parse(reply.to_hash["response"][:body])
      profiles_received.each do |a_profile_url|
        if !profiles.key?(a_profile_url)
          # stub structure def
          stub_structure_def = FHIR::StructureDefinition.new()
          stub_structure_def.url = a_profile_url
          profiles[a_profile_url] = stub_structure_def
        end
      end
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
      script = dynamic_variable(script) if script.variable && variable
      runnables[script.name] = TestScriptRunnable.new(script, get_fixtures, options, profiles)
    else
      scripts.each do |_name, script|
        info(:creating_runnable, script.name)
        script = dynamic_variable(script) if script.variable && variable
        runnables[script.name] = TestScriptRunnable.new(script, get_fixtures, options, profiles)
      end
    end
  rescue StandardError
    error(:unable_to_create_runnable, script.name)
  end

  def dynamic_variable(script)
    script.variable.each do |v|
      variable.each do |v2|
        v.defaultValue = v2.split("=").last if v2.split("=").first == v.name && v.defaultValue != nil
      end
    end
    return script
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

    summary_rows = [["id", "name", "title", "result"]]

    reports.each do |report_key, report|
      report_name = report.name.downcase.split(' ')[1...].join('_')
      report_name = report.name.downcase.split('_')[0...].join('_') if report_name == ''
      File.open("#{report_directory}/#{report_name}.json", 'w') do |f|
        f.write(report.to_json)
      end
      test_script = runnables[report_key]
      summary_rows << [test_script.script.id, test_script.script.name, """#{test_script.script.title}""", report.result]
    end

    if options["summary_path"] != nil
      summary_path = File.join(Dir.getwd, options["summary_path"])
      FileUtils.mkdir_p summary_path
      File.write(File.join(summary_path, "execution_summary_#{Time.now.utc.iso8601}.csv"), summary_rows.map(&:to_csv).join)
    end


  end
end
