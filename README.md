# About the Project

The TestScript Engine is an open source, command-line tool for executing tests described by [Fast Healthcare Interoperability Resources (FHIR)](http://hl7.org/fhir/) TestScript instances. The key goals of the project include: 

* Align with and help to further develop the FHIR standard's approach to [testing](http://www.hl7.org/fhir/testing.html)
* Provide to the FHIR community with an open source implementation that can execute tests described by [TestScript](http://www.hl7.org/fhir/testscript.html) instances.
* Generate results that help testers understand the results of a test run using [TestReport](http://www.hl7.org/fhir/testreport.html) instances
* Support integration with additional FHIR IG authoring, implementation, and testing tools, such as the [TestScript Generator](https://github.com/fhir-crucible/testscript-generator) and [Synthea](https://github.com/synthetichealth/synthea).

## Running the Engine

There are two methods for running the TestScript Engine:

 * **WITHIN THIS REPO**

Clone [this repository](https://github.com/fhir-crucible/testscript-engine) and navigate to your local copy. Once there, run: `bundle install` followed by `bundle exec bin/testscript_engine`. This will start the engine within the context of your local copy.

This is the recommended method if you don't have TestScripts of your own, as this repository includes sample TestScripts in the `./TestScripts` folder for processing and execution.

* **FROM ANYWHERE**

First, download the TestScript gem by running: `gem install testscript_engine`.
Then, launch the engine by running: `testscript_engine`.

This is the recommended method if you already have a collection of your own TestScripts, as it allows you the freedom of running the engine from within your TestScript repository (or anywhere).

## Configure the Engine

The engine can be configured through three methods: configuration file, commandline arguments, and interactive mode.

### Configuration file

Running the engine on a configuration file provides testing on predefined settings.

`bundle exec bin/testscript_engine execute --config [FILEPATH]` : Put name and path of configuration YAML file.

Below are properties in the configuration files.
- `testscript_name : [TESTSCRIPT.NAME]` Name of TestScript to be executed. If empty, all files under testscript_path will be executed.
- `testscript_path : [PATH]` The relative path to the directory containing the TestScript resources (as JSON or XML) to be executed by the engine.
- `testreport_path : [PATH]` The relative to the directory containing the TestReports output following their partner TestScript execution.
- `summary_path : [PATH]` If specified, a summary report csv file named execution_summary_[UTC timestamp].csv will be created within the specified relative folder. The file will include the id, name, and title of each TestScript executed and the overall pass/fail result. For systems without robust TestReport capabilities, provides an easy way to view the results of a test run across multiple scripts.
- `variable : [- name1=value1 - name2=value2 ..]`: Replace defaultValue in variable by user defined value. This will apply to all runnables uniformly as long as names match. No space before and after =. Multiple variables are distinguished by line.
- `profile : [- location1 - location2 ..]`: List of locations holding profile StructureDefinitions to be used for profile validation. May be a web url, a relative file, or a relative directory (profiles in sub-directories not included). StructureDefinitions loaded from this configuration setting take precedence over StructureDefinitions accessed from canonical URLs in TestScripts that resolve to StructureDefinitions. This allows for validation against unpublished versions of profiles.
- `server_url : [URL]` Endpoint against which TestScripts will be executed.
- `nonfhir_fixture : [TRUE/FALSE]` If yes, allow to intake non-FHIR fixture (local only).
- `ext_validator : [URL]` If specified, use external resource validator instead of internal validator.
- `ext_fhirpath : [URL]` If specified, use external FHIR path evaluator instead of internal evaluator.

### Commandline Arguments

Command line arguments can be used when you want to run specific files and/or conditions. Run the engine with the following format:

`bundle exec bin/testscript_engine execute [OPTIONS]`

[OPTIONS]
- `--config [FILENAME]`: Name of configuration file.
- `--testscript_name [TESTSCRIPT.NAME]`: Name of TestScript to be execute. If not specified, all files under testscript_path will be executed.
- `--testscript_path [PATH]`: Folder location of TestScripts (default: /TestScripts)
- `--testreport_path [PATH]`: Folder location of TestReports (default: /TestReports)
- `--summary_path [PATH]` If specified, a summary report csv file named execution_summary_[UTC timestamp].csv will be created within the specified relative folder. The file will include the id, name, and title of each TestScript executed and the overall pass/fail result. For systems without robust TestReport capabilities, provides an easy way to view the results of a test run across multiple scripts.
- `--server_url [URL]`: If specified, it will replace the default FHIR server in the configuration file.
- `--variable [name1=value1 name2=value2 ..]`: Replace defaultValue in variable by user defined value. This will apply to all runnables uniformly as long as names match. No space before and after =. Use quotations if value has space.
- `--profile [location1 location2 ..]`: List of locations holding profile StructureDefinitions to be used for profile validation. May be a web url, a relative file, or a relative directory (profiles in sub-directories not included). StructureDefinitions loaded from this configuration setting take precedence over StructureDefinitions accessed from canonical URLs in TestScripts that resolve to StructureDefinitions. This allows for validation against unpublished versions of profiles.
- `--nonfhir_fixture [TRUE/FALSE]`: If yes, allow to intake non-FHIR fixture (local only).
- `--ext_validator [URL]`: If specified, use external resource validator.
- `--ext_fhirpath [URL]`: If specified, use external FHIR path evaluator.

### Interactive mode

Running the engine on interactive mode provides flexibility to change the properties while executing testing. Simply run the command below.

`bundle exec bin/testscript_engine interactive`

## Folders and Files

TestScripts are validated and loaded in by the engine. By default, the engine looks for a `./TestScripts` folder in its given context, but will allow the user to specify an alternate path. Once scripts are loaded, they are converted into 'runnables'. The engine allows users to specify which runnable to execute, and by default will execute all available runnables. Likewise, the user can specify the endpoint upon which the runnable(s) should be executed. Following execution, the user can either re-execute -- specifying a different runnable or endpoint -- or shut-down the engine. Finally, the results from each runnable's latest execution are written out to the `./TestReports` folder.

  - `./lib`
    - `assertion.rb`
    - `operation.rb`
    - `testscript_runnable.rb`
    - `testreport_handler.rb`
    - `message_handler.rb`
  - `testscript_engine.rb`
  - `run.rb`
  - `./spec`
  - `./TestReports`
  - `./TestScripts `
    - `./fixtures`

`./lib`:
  - `assertion.rb`
      - Contains the asserts used during assertion handling within the TestScriptRunnable class.
  - `operation.rb`
      - Contains the operation-related methods and logic used during operation execution within the TestScriptRunnable class.
  - `run.rb`
      - Creates an instance of the engine, loads in the TestScript resources located within the TestScript directory, and runs them against the default endpoint. It demonstrates the start to finish process of using the TestScriptEngine to execute TestScripts.
  - `testscript_engine.rb`
      - Home of the TestScriptEngine class. The engine deals with loading in json TestScript files, managing their transformation into runnables, and ultimately their execution. It is the engine's responsibiliy to direct and leverage a runnable against (an) endpoint(s).
  - `testscript_runnable.rb`
      - TestScriptRunnable class is an object containing the code necessary to execute a TestScript. The runnable of a TestScript was designed with the idea that, after its initialization, is could be pointed at and run against any number of endpoints without reloading the original TestScript. Setup, Tests, and Teardown actions are executed in that order, with Setup and Teardown actions factored into the overall score given as part of the TestReport output.
  - `testreport_handler.rb`
      - Class for creating and updating the TestReport resource. The report's skeleton is generated using the corresponding TestScript, though the action results are left blank and populated as directed during TestScript execution. As a result, the report is synchronous with the runnable class and relies on the TestScriptRunnable to communicate the result of an action execution or evaluation.
  - `message_handler.rb`
      - Module for all command-line logging functionality and adding messages to FHIR resources.

`./spec`:
  - Folder containing all existing unit tests for both TestScriptEngine and TestScriptRunnable

`./TestReports`:
  - Folder containing the TestReport(s) created while executing (a) given TestScript(s).

`./TestScripts`:
  - Folder that contains the TestScripts to be executed. Any example resources used within those TestScripts (i.e. using a patient resource as a fixture) should be located within the `./fixtures` subfolder.

## Features
### Assertion
The engine uses various algorithms to evaluate the results of previous operations to determine if the server under test behaves appropriately.
* minimum_id: Per the [TestScript specification](http://www.hl7.org/fhir/testscript-definitions.html#TestScript.setup.action.assert.minimumId), an assertion with the minimumId element populated asserts that the target instance (current response or instance pointed to by sourceId) "contains all the element/content" from the minimumId instance (the instance pointed to by the minimumId element). For the implementation within this engine, an assertion with minimumId specified passes if and only if each element and list entry within the minimumId instance can be found within the target instance at the same levels within the heirarchy. With respect to lists, entries are not required to appear at the same index or in the same order. Instead, for each entry within the minimumId instance the engine must find a unique corresponding list entry within the target instance that contains all of the elements and content in the minimumId instance's entry. Note that the engine takes a greedy approach to identifying list entries that match, which means there exist pathological cases for which the implementation fails to find matches when they do in fact exist.

## Limitations
The TestScript Engine is still in the infancy of its development; it is neither fully complete nor bug-free and we encourage contributions, feedback, and issue-opening from the community. There are known gaps in the TestScript Engine:

* Support for validateProfileId
* Support for use of an external validator
* Support for multiple origins and/or destinations

## References

* [Testing FHIR](https://build.fhir.org/testing.html)
* [FHIR Resource: TestScript](https://build.fhir.org/testscript.html)
* [FHIR Resource: TestReport](https://build.fhir.org/testreport.html)
* [Crucible](https://github.com/fhir-crucible)

## License
Copyright 2022 The MITRE Corporation

Licensed under the Apache License, Version 2.0 (the "License"); you may not use
this file except in compliance with the License. You may obtain a copy of the
License at
```
http://www.apache.org/licenses/LICENSE-2.0
```
Unless required by applicable law or agreed to in writing, software distributed
under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
CONDITIONS OF ANY KIND, either express or implied. See the License for the
specific language governing permissions and limitations under the License.
