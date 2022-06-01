## About the Project

The purpose of the TestScript Engine is to support and encourage essential aspects of FHIR testing through the following features:

* General purpose engine to be implemented in various use cases
* Intake and execution of FHIR TestScript resources and output of TestReport resources that summarize the result of executing each TestScripts against a given endpoint or system 
* Aligned with existing FHIR architecture
* Extensible to be integrated with key FHIR toolchains in the future (FHIR Shorthand, [TestScript Generator](https://github.com/fhir-crucible/testscript-generator), Synthea)  

### Limitations

TestScript Engine is in the early stages of development; it is neither functionally complete nor bug-free and we encourage contributions, feedback, and issue-opening from the community.


### Getting started

**Commands:**
  ```
    cd lib
    ruby driver.rb
  ```

  - Functionality
    - This runs the driver, which is currently the means for running and testing using the engine and runnable class. TestScripts to be run must be added to the TestScripts directory.

**Folders and Files:**
  - `./lib`
    - driver.rb
    - assertions.rb
    - TestScriptEngine.rb
    - TestScriptRunnable.rb
    - TestReportHandler.rb
    - MessageHandler.rb
  - `./spec`
  - `./TestReports`
  - `./TestScripts `
    - `./fixtures`

`./lib`:
  - assertions.rb
      - Contains the hard-coded assertions used during assertion handling within the TestScriptRunnable class.
  - driver.rb
      - Starter file that creates an instance of the engine, loads in the TestScript resources located within the TestScript directory, and runs them against the public Hapi FHIR endpoint. It demonstrates the start to finish process of using the TestScriptEngine to run TestScripts in their json file format.
  - TestScriptEngine.rb
      - Home of the TestScriptEngine class. The engine deals with loading in json TestScript files, managing their transformation into runnables, and ultimately their execution. It is the engine's responsibiliy to direct and leverage a runnable against (an) endpoint(s).
  - TestScriptRunnable.rb
      - TestScriptRunnable class is an encapsulation of all the information needed to run a TestScript json resource. The runnable of a TestScript was designed with the idea that, after its initialization, is could be pointed at and run against any number of endpoints without reloading the original TestScript json resource. Setup, Tests, and Teardown actions are executed in that order, with Setup and Teardown actions factored into the overall score given as part of the TestReport output. 
  - TestReportHandler.rb
      - Class for creating and updating the TestReport resource. The report's skeleton is generated using the corresponding TestScript, though the action results are left blank and populated as directed during TestScript execution. As a result, the report is synchronous with the runnable class and relies on the TestScriptRunnable to communicate the result of an action execution or evaluation.
  - MessageHandler.rb
      - Module for all command-line logging functionality and adding messages to FHIR resources. 


`./spec`:
  - Folder containing all existing unit tests for both TestScriptEngine and TestScriptRunnable

`./TestReports`:
  - Folder containing the TestReport(s) created while executing (a) given TestScript(s).  

`./TestScripts`:
  - Folder that contains the TestScripts to be executed. Any example resources used within those TestScripts (i.e. using a patient resource as a fixture) should be located within the `./fixtures` subfolder. 

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
