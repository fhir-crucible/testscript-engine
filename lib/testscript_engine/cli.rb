# frozen_string_literal: true
require 'yaml'
require 'thor'

class TestScriptEngine

  module CLI 
    class MyCLI < Thor
      desc "execute [OPTIONS]", "--nonfhir_fixture --ext_validator [URL] --ext_fhirpath [URL] --server_url [URL] --testscript_path [FILEPATH] --testreport_path [FILEPATH]"
      option :config
      option :nonfhir_fixture
      option :ext_validator
      option :ext_fhirpath
      option :server_url
      option :testscript_path
      option :testscript_name
      #We will change later to accommodate multiple testscript names
      #option :testscript_name, :type => :array
      option :testreport_path
      def execute()
        if options == {}
          puts "No argument to run to engine. Run 'bundle exec bin/testscript_engine option' to see available arguments" 
          exit
        end
        return options
      end

      desc "interactive", "Run the engine based on interactive mode. Rest of arguments will be ignored."
      def interactive()
        return {"interactive" => true} if options == {}
      end

      # Empty method to hide default Thor message
      desc "", ""
      def help()
      end

      desc "option", "Show all options"
      def option()
        puts "bundle exec bin/testscript_engine [OPTIONS]"
        puts "  interactive: run on interactive mode. Rest of arguments will be ignored."
        puts "  execute --config [FILEPATH]: run on configuration file on the path."
        puts "  execute --nonfhir_fixture [true/false]: allow to intake non-FHIR fixture"
        puts "  execute --ext_validator [URL]: when specified, use external resource validator"
        puts "  execute --ext_fhirpath [URL]: when specified, use external FHIR path evaluator"
        puts "  execute --server_url [URL]: when specified, replace the default FHIR server"
        puts "  execute --testscript_path [FILEPATH]: TestScript location (default: /TestScripts)"
        puts "  execute --testreport_path [FILEPATH]: TestReport location (default: /TestReports)"
      
        exit
      end
      
    end

    def self.start
  
      @test_server_url = "http://server.fire.ly"
      @testscript_path = "./TestScripts"
      @testreport_path = "./TestReports"
      @load_non_fhir_fixtures = true
      @ext_validator = nil
      @ext_fhirpath = nil

      options = MyCLI.start(ARGV)

      if options != nil
        @interactive = options["interactive"]
  
        if @interactive == nil
          config = options["config"]

          if config != nil
            begin
              ymloptions = YAML.load(File.read(config))
              puts "Successfully loaded custom config file: #{config}"
              options = ymloptions.merge(options)
            rescue
              puts "Failed to open file: #{config}"
              exit
            end
          end
        end
      else
        options = {}
      end

      @test_server_url = options["server_url"] if options["server_url"]
      @testscript_path = options["testscript_path"] if options["testscript_path"]
      @testreport_path = options["testreport_path"] if options["testreport_path"]
      @load_non_fhir_fixtures = options["nonfhir_fixture"] if options["nonfhir_fixture"]
      runnable = options["testscript_name"] if options["testscript_name"]
      runnable = "TestScript_Example_ValidateProfileId"

      Dir.glob("#{Dir.getwd}/**").each do |path|
        @testscript_path = path if path.split('/').last.downcase == 'testscripts'
        @testreport_path = path if path.split('/').last.downcase == 'testreports'
      end

      if (@interactive)
        print "Hello from the TestScriptEngine! "
        approve_configuration
      end

      engine = TestScriptEngine.new(@test_server_url, @testscript_path, @testreport_path, options)
      engine.load_input
      engine.make_runnables

      print "Now able to execute runnables. \n" if (@interactive)

      while true
        if (@interactive)
          puts
          print "The SERVER UNDER TEST is [#{@test_server_url}]. Would you like to change the SERVER UNDER TEST? [Y/N] "
          input = STDIN.gets.chomp
          if input.strip.downcase == 'y'
            puts
            print "Set [SERVER UNDER TEST]: "
            input = STDIN.gets.chomp
            @test_server_url = input unless input.strip == ""
            engine.new_client(@test_server_url)
          end

          puts
        end
        
        if (@interactive)
          print "Enter the ID of a runnable to execute, or press return to execute all runnables: "
          runnable = STDIN.gets.chomp
          if runnable.strip == ''
            runnable = nil
          else
            while !engine.verify_runnable(runnable)
              print "	Invalid runnable ID given. Please try again: "
              runnable = STDIN.gets.chomp
            end
          end
        elsif (runnable != nil) && !engine.verify_runnable(runnable)
          raise ArgumentError.new("invalid runnable provided via command line argument: #{runnable}")
        end

        engine.execute_runnables(runnable)

        if (@interactive)
          puts
          print "Execution finished. Enter (q) to quit, press any other key to continue execution: "
          input = STDIN.gets.chomp
          break if input == 'q'
        else 
          break
        end
      end

      engine.write_reports

      print "Goodbye!" if (@interactive)
    end
    
    def self.configuration
      %(The configuration is as follows: \n
        SERVER UNDER TEST: [#{@test_server_url}]
        LOAD NON-FHIR FIXTURES: [#{@load_non_fhir_fixtures.to_s.upcase}]
        TESTSCRIPT INPUT DIRECTORY or FILE: [#{@testscript_path}]
        TESTREPORT OUTPUT DIRECTORY: [#{@testreport_path}] \n
      Would you like to modify this configuration? [Y/N] )
    end

    def self.validate_path(path)
      while true
        break if File.file?(path) || File.directory?(path)
        print "	Invalid file or directory path given. Current working directory: [#{Dir.getwd}]. Try again: "
        path = STDIN.gets.chomp
      end
      path
    end

    def self.modify_configuration
      print "Set [SERVER UNDER TEST] (press return to skip): "
      input = STDIN.gets.chomp
      @test_server_url = input unless input.strip == ""

      print "Set [LOAD NON-FHIR FIXTURES] (expecting T/F, press return to skip): "
      input = STDIN.gets.chomp
      unless input.strip == ""
        @load_non_fhir_fixtures = (input.downcase == 'f' ? false : true )
      end

      print "Set [TESTSCRIPT INPUT DIRECTORY or FILE] (press return to skip): "
      input = STDIN.gets.chomp
      unless input.strip == ""
        @testscript_path = validate_path(input.strip)
      end

      print "Set [TESTREPORT OUTPUT DIRECTORY] (press return to skip): "
      input = STDIN.gets.chomp
      unless input.strip == ""
        @testreport_path = validate_path(input.strip)
      end

      puts
    end

    def self.approve_configuration
      while true
        print configuration
        input = STDIN.gets.chomp
        puts
        if input.strip.downcase == 'y'
          modify_configuration
        else
          break
        end
      end
    end
  end
end
