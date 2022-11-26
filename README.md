# About the Project

The TestScript Engine is an open source, command-line tool for executing [Fast Healthcare Interoperability Resources (FHIR)](http://hl7.org/fhir/) TestScript resources. The key deatures are: 

* General use engine to be implemented in various use cases
* Intake and execute FHIR TestScript resources
* Output TestReport resources that summarize the result of executing each TestScripts against a given endpoint or system
* Aligned with standard FHIR architecture
* Extensible to be integrated with key FHIR toolchains in the future (FHIR Shorthand, [TestScript Generator](https://github.com/fhir-crucible/testscript-generator), Synthea)

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

The engine can be configured through several variables, each of which has a preset value that can be modifed during runtime:

- `TEST_SERVER_URL`: The endpoint against which the runnables will be executed.
- `LOAD_NON_FHIR_FIXTURES`: Whether to ignore non-FHIR fixtures. Non-FHIR fixtures are not currently supported by the [spec](https://build.fhir.org/testscript.html), however we recognize several use cases where they would be valuable. Expects [T/F].
- `TESTSCRIPT_PATH`: The relative path to the directory containing the TestScript resources (as JSON or XML) to be executed by the engine. If any TestScript in the directory uses a fixture, the directory MUST also include a `fixtures` subfolder containing files whose relative paths match the reference value of a fixture within a TestScript.
- `TESTREPORT_PATH`: The relative to the directory containing the TestReports output following their partner TestScript execution.

### Commandline Arguments

Some configurations can be set using command line arguments:
- `-r` or `--runnable`: the next argument must be the name of runnable to execute (from `TestScript.name`). Only works if the noninteractive flag is provided. 
- `-n` or `--noninteractive`: disable confirmation of configuration settings

For example, to execute the TestScript runnable in file `TestScripts/read_testscript.json` (with name `TestScript Example Read Test`) in non-interactive mode, execute `bundle exec bin/testscript_engine -n -r "TestScript Example Read Test"`.

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
* minimum_id: Asserts that the response contains at a minimum the fixture specified by minimumId. The definition of minimum is if and only if the response has all the FHIR resource elements of the minimumId fixture, with exactly same element names, values, levels and hierarchies. No consideration of range, pre/post-coordination, or order of the items.

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
