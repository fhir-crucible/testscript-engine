# frozen_string_literal: true
require 'yaml'
require 'thor'

class TestScriptEngine

  module CLI 
    class MyCLI < Thor
      desc "execute [OPTIONS]", "--config --ext_validator [URL] --ext_fhirpath [URL] --variable ['name = value'] --server_url [URL] --testscript_path [FILEPATH] --testreport_path [FILEPATH] --nonfhir_fixture --verbose"
      option :config
      option :testscript_path
      option :testscript_name
      option :testreport_path
      option :server_url
      option :nonfhir_fixture, :type => :boolean
      option :variable, :type => :array
      option :verbose, :type => :boolean
      option :ext_validator
      option :ext_fhirpath
      def execute()
        if options == {}
          puts "No argument to run the engine. See README.MD to find available options" 
          exit
        end
        return options
      end

      desc "interactive", "Run the engine based on interactive mode."
      def interactive()
        return {"interactive" => true} if options == {}
      end

    end

    def self.start
  
      @test_server_url = "http://server.fire.ly"
      @testscript_path = "/TestScripts"
      @testscript_name = nil
      @testreport_path = "/TestReports"
      @load_non_fhir_fixtures = true
      
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
        options = {"ext_validator" => "inferno", "ext_fhirpath" => nil, "verbose" => false}
      end
      
      @test_server_url = options["server_url"] if options["server_url"]
      @testscript_path = options["testscript_path"] if options["testscript_path"]
      @testreport_path = options["testreport_path"] if options["testreport_path"]
      @load_non_fhir_fixtures = options["nonfhir_fixture"] if options["nonfhir_fixture"]
      runnable = options["testscript_name"] if options["testscript_name"]
      
      @testscript_path = Dir.getwd + @testscript_path
      @testreport_path = Dir.getwd + @testreport_path

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