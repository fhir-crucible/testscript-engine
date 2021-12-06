Commands:
  bundle exec spec 
    - Instructions
      - Run from within the root folder -- not from within ./lib or ./spec
    - Functionality
      - Runs all existing unit tests using rspec
  ruby test-driver.rb
    - Note
      - Run from within ./lib
    Functionality
      - Runs the driver, which is the primary means for running and testing 
        existing functionality of the TestScriptEngine and TestScriptRunnable
        classes.  

Folders:
  - lib
    - assertions.rb
    - test-driver.rb
    - TestScriptEngine.rb
    - TestScriptRunnable.rb
  - spec
    - spec_tScripts
  - TestReports
  - TestScripts 
    - ExampleResources

lib:
  - assertions.rb
      Contains the hard-coded assertions used during assertion handling within
      the TestScriptRunnable class.
  - test-driver.rb
      Driver that tests, piecewise, the available functionality of the 
      TestScriptEngine class. It demonstrates the start to finish process of 
      using the TestScriptEngine to run TestScripts in their json file format.
  - TestScriptEngine.rb
      Home of the TestScriptEngine class. TestScriptEngine design aimed to make
      the class as flexible and open as possible, with all methods and 
      attributes exposed to users of the class. The engine really deals with 
      centralizing the execution process - from TestScript input to TestReport
      output - while allowing a user to inspect, replace, or cherry-pick any of
      the pieces that comprise that process. It is the engine's responsibiliy 
      to leverage a runnable against an endpoint.
  - TestScriptRunnable.rb
      Home of the TestScriptRunnable class. TestScriptRunnable design aimed to 
      turn a TestScript object into a callable method, where calling that 
      method would initiate execution -- from loading fixtures to teardown -- 
      on whichever endpoint the engine points the runnable towards. The idea is
      that a runnable contained within one method has a ton of potential value
      when we reach the point where we are chaining the execution of multiple, 
      individual TestScripts together.

spec:
  Folder containing all existing unit tests for both TestScriptEngine and 
  TestScriptRunnable
  - spec_tScripts
      Folder containing sample TestScript json files necessary for unit testing
      functionality within the TestScriptRunnable class.

TestReports:
  Folder containing the TestReport(s) created while executing (a) given 
  TestScript(s).  

TestScripts:
  Folder that contains the TestScripts to be executed. Any example resources 
  used within those TestScripts (i.e. using a patient resource as a fixture) 
  should be located within the ExampleResources subfolder. 

TODO:
  - Unit tests for TestScriptEngine Class
  - Clean-up/simplify unit tests for TestScriptRunnable 
  - Create a mapping of Inferno assertions to the assertions used within 
    TestScriptRunnable
  - Clean up error handling in TestScriptRunnable

  *Note - Search TODO in any file to explore what work still needs to be done. 
