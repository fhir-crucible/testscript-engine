require 'fhir_client'
require './TestScriptRunnable'
require 'pry-nav'

class TestScriptEngine

	attr_accessor :tScripts

	def initialize(server_url)
		@client = FHIR::Client.new(server_url)
		@tScripts = []
		@executables = []
		@reports = []
	end 

	# Execute each runnable stored within @executables and store the TestReport 
	# object that gets returned after each execution within @reports.
	def execute_tScripts
		@executables.each do |script|
			@reports << script.execute
		end 
	end 

	# Write out each TestReport object stored within in @reports to the
	# TestReports folder.
	def write_tReport
		@reports.each do |report|
			File.write("../TestReports/#{report.id}.json", report.to_json)
		end 
	end 

	# Converts the TestScript objects contained in @tScripts into 
	#	TestScriptRunnables and stores them in @executables.
	# 
	# @params tScript [TestScript obj.] Optional param that, if given, will be
	#																		converted into a TestScript runnable and
	#																		stored in @executable. Resultantly, 
	#																		@tScripts is ignored.
	def create_runnables(tScript = nil)
		
		if tScript && tScript.is_a?(FHIR::TestScript) && tScript.valid?
			FHIR.logger.info '[TestScriptEngine.create_runnables] Using given tScript.'
			@executables << TestScriptRunnable.new(tScript)
		else
			FHIR.logger.info '[TestScriptEngine.create_runnables] Using @tScripts.'
			@executables << TestScriptRunnable.new(@tScripts) 
		end 
	end 


	# Reads in TestScript json files and loads them into @tScripts as TestScript 
	#	objects. Sets the url of each TestScript object to the relative path of its 
	#	source file.
	#
	# @param path [String] Relative path (relative to lib folder) leading to 
	# 										 the folder containing TestScripts to be executed. 
	def read_tScript_resources(path)
		tScript_resources = Dir.glob(path + '/**/*')
		tScript_resources.each do |resource|
			begin
				tScript = FHIR.from_contents(File.read(resource))
				if tScript.is_a?(FHIR::TestScript) && tScript.valid?
					tScript.url = resource
					@tScripts << tScript
					FHIR.logger.info "[TestScriptEngine.read_tScript_resources] Loaded #{resource}"
				elsif script.is_a?(FHIR::TestScript)
					FHIR.logger.error "[TestScriptEngine.read_tScript_resources] Skipping invalid TestScript #{resource}"
				else 
					FHIR.logger.warn "[TestScriptEngine.read_tScript_resources] Skipping resource #{resource}"
				end
			rescue
				FHIR.logger.error "[TestScriptEngine.read_tScript_resources] Exception deserializing TestScript #{resource}"
			end
		end
	end 
end 