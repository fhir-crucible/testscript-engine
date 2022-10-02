class TestScriptEngine
	module CLI
		def self.start
			@test_server_url = "http://hapi.fhir.org/baseR4"
			@testscript_path = "./"
			@testreport_path = "./TestReports"

			Dir.glob("#{Dir.getwd}/**").each do |path|
					@testscript_path = path if path.split('/').last.downcase == 'testscripts'
					@testreport_path = path if path.split('/').last.downcase == 'testreports'
			end

		def self.configuration
		%(The configuration is as follows: \n
				SERVER UNDER TEST: [#{@test_server_url}]
				TESTSCRIPT INPUT DIRECTORY or FILE: [#{@testscript_path}]
				TESTREPORT OUTPUT DIRECTORY: [#{@testreport_path}] \n
		Would you like to modify this configuration? [Y/N] )
		end

		def self.validate_path(path)
				while true
						break if File.file?(path) || File.directory?(path)
						print "	Invalid file or directory path given. Current working directory: [#{Dir.getwd}]. Try again: "
						path = gets.chomp
				end
				path
		end

		def self.modify_configuration
			print "Set [SERVER UNDER TEST] (press return to skip): "
			input = gets.chomp
			@test_server_url = input unless input.strip == ""

			print "Set [TESTSCRIPT INPUT DIRECTORY or FILE] (press return to skip): "
			input = gets.chomp
			unless input.strip == ""
					@testscript_path = validate_path(input.strip)
			end

			print "Set [TESTREPORT OUTPUT DIRECTORY] (press return to skip): "
			input = gets.chomp
			unless input.strip == ""
					@testreport_path = validate_path(input.strip)
			end

			puts
		end

		def self.approve_configuration
			while true
				print configuration
				input = gets.chomp
				puts
				if input.strip.downcase == 'y'
					modify_configuration
				else
					break
				end
			end
		end

			print "Hello from the TestScriptEngine! "
			approve_configuration

			engine = TestScriptEngine.new(@test_server_url, @testscript_path, @testreport_path)
			engine.load_scripts
			engine.make_runnables

			print "Now able to execute runnables. \n"

			while true
					puts
					print "The SERVER UNDER TEST is [#{@test_server_url}]. Would you like to change the SERVER UNDER TEST? [Y/N] "
					input = gets.chomp
					if input.strip.downcase == 'y'
							puts
							print "Set [SERVER UNDER TEST]: "
							input = gets.chomp
							@test_server_url = input unless input.strip == ""
							engine.new_client(@test_server_url)
					end

					puts

					print "Enter the ID of a runnable to execute, or press return to execute all runnables: "
					input = gets.chomp
					if input.strip == ''
							input = nil
					else
							while !engine.verify_runnable(input)
									print "	Invalid runnable ID given. Please try again: "
									input = gets.chomp
							end
					end

					engine.execute_runnables(input)

					puts
					print "Execution finished. Enter (q) to quit, and press any other key to continue execution: "
					input = gets.chomp
					break if input == 'q'
			end

			engine.write_reports

			print "Goodbye!"
		end
	end
end