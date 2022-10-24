module MessageHandler
  attr_accessor :debug_mode, :modify_report

  def space
    @space ||= ''
  end

  def unit_of_space
    "   "
  end

  def increase_space
    space << unit_of_space
  end

  def decrease_space
    @space.chomp!(unit_of_space)
  end

  def newline
    puts
  end

  def print_out(message)
    if message.start_with?("START")
      newline
      increase_space
    elsif message.start_with?("FINISH")
    else
      print unit_of_space
    end
    print space
    puts message

    if message.start_with?("FINISH")
      decrease_space
    end
    nil
  end

  def info(message_type, *options)
    print_out messages(message_type, *options)
  end

  def execution_results
    puts
    print_out "SUMMARY OF EXECUTION RESULTS: "
  end

  def pass_execution_results(results)
    increase_space
    results.each do |result|
      print_out messages(:pass_execution_result, result)
    end
    puts
    decrease_space
  end

  def see_reports(testreport_path)
    puts
    print_out messages(:see_reports, testreport_path)
  end

  def fail_execution_results(results)
    increase_space
    results.each do |result|
      print_out messages(:fail_execution_result, *result)
    end
    decrease_space
  end

  def cascade_skips(message_type, actions, *options)
    print_out "#{outcome_symbol("SKIP")} #{messages(message_type, *options)}"
    increase_space
    counter = 0
    while counter < actions.length
      action = actions[counter]
      if action.operation
        id = "Operation: [#{(action.operation.id || action.operation.label || 'unlabeled')}]"
      else
        id = "Assert: [#{(action.assert.id || action.assert.label || 'unlabeled')}]" if action.assert
      end
      skip(:eval_assert_result, "#{id} skipped.")
      counter += 1
    end
    decrease_space
  end

  def load_scripts
    print_out messages(:begin_loading_scripts, testscript_path)
    super
    print_out messages(:finish_loading_scripts)
  end

  def make_runnables
    print_out messages(:begin_creating_runnables)
    increase_space
    super
    decrease_space
    print_out messages(:finish_creating_runnables)
  end

  def run(*args)
    print_out messages(:begin_runnable_execution, script.id)
    result = super
    puts
    print_out messages(:finish_runnable_execution)
    result
  end

  def preprocess
    print_out messages(:begin_preprocess)
    super
    print_out messages(:finish_preprocess)
  end

  def setup
    print_out messages(:begin_setup)
    super
    print_out messages(:finish_setup)
  end

  def test
    print_out messages(:begin_test)
    super
    print_out messages(:finish_test)
  end

  def teardown
    print_out messages(:begin_teardown)
    super
    print_out messages(:finish_teardown)
  end

  def postprocessing
    print_out messages(:begin_postprocess)
    super
    print_out messages(:finish_preprocess)
  end

  def load_fixtures
    increase_space
    super
    decrease_space
  end

  def pass(message_type, *options)
    message = messages(message_type, *options)
    super()
    print_out "#{outcome_symbol("INFO")} #{message}"
  end

  def fail(message_type, *options)
    message = messages(message_type, *options)
    super(message) if modify_report
    print_out "#{outcome_symbol("FAIL")} #{message}"
  end

  def skip(message_type, *options)
    message = messages(message_type, *options)
    super(message) if modify_report
    print_out "#{outcome_symbol("SKIP")} #{message}"
  end

  def warning(message_type, *options)
    message = messages(message_type, *options)
    super(message) if modify_report
    print_out "#{outcome_symbol("WARN")} #{message}"
  end

  def error(message_type, *options)
    message = messages(message_type, *options)
    super(message) if modify_report
    print_out "#{outcome_symbol("ERROR")} #{message}"
  end

  def print_action_header(action_type)
    return false if @previous_action_type == action_type

    @previous_action_type = action_type
    true
  end

  # < ---- TO REVIEW ---- >
  def client(*args)
    client = super
    FHIR.logger.formatter = logger_formatter_with_spacing
    client
  end

  def logger_formatters_with_spacing
    @logger_formatters_with_spacing ||= {}
  end

  def logger_formatter_with_spacing
    logger_formatters_with_spacing[space.length] || begin
      new_logger_formatter = proc do |severity, datetime, progname, msg|
        "#{space}#{unit_of_space}#{msg}\n"
      end
      logger_formatters_with_spacing[space.length] = new_logger_formatter
      new_logger_formatter
    end
  end

  def outcome_symbol(outcome)
    symbol = begin
      case outcome
      when "UNKNOWN"
        "?¿?"
      when "FATAL"
        [023042].pack("U*")
      when "ERROR"
        [10071].pack("U*")
      when "WARN"
        [023220].pack("U*")
      when "INFO"
        [10003].pack("U*")
      when "DEBUG"
        [0372415].pack("U*")
      when "FAIL"
        [10007].pack("U*")
      when "SKIP"
        "\u21BB".encode('utf-8')
      end
    end

    "(#{symbol})"
  end

  def begin_symbol
    [10551].pack("U*")
  end

  def finish_symbol
    [024465].pack("U*")
  end

  def messages(message, *options)
    message_text = case message
    when :abort_test
      "Due to an unsuccessful action in the [#{options[0]}] phase, remaining actions in this test will be skipped. Skipping the next #{options[1]} action(s)."
    when :bad_script
      "Given non-TestScript resource. Can not create runnable."
    when :bad_serialized_script
      "Can not deserialize resource into TestScript: [#{options[0]}]."
    when :begin_initialize_client
      start_message_format("INITIALIZE CLIENT")
    when :begin_creating_runnables
      start_message_format("MAKE RUNNABLE(S)")
    when :created_runnable
      "Created runnable from TestScript: [#{options[0]}]."
    when :finish_creating_runnables
      finish_message_format("MAKING RUNNABLE(S)")
    when :finish_initialize_client
      finish_message_format("INITIALIZING CLIENT")
    when :invalid_script
      "Can not load TestScript. Invalid resource: [#{options[0]}]."
    when :invalid_script
      "Given invalid TestScript resource. Can not create runnable."
    when :loaded_script
      "Successfully loaded."
    when :loaded_static_fixture
      "Loaded static fixture [#{options[0]}]."
    when :no_postprocess
      "Nothing to postprocess."
    when :no_preprocess
      "Nothing to preprocess."
    when :no_setup
      "Nothing to setup."
    when :no_teardown
      "Nothing to teardown."
    when :overwrite_existing_script
      "Overwriting previously loaded TestScript: [#{options[0]}]."
    when :skip_on_fail
      "Due to the preceeding unsuccessful action, skipping the next #{options[0]} action(s)."
    when :unable_to_create_runnable
      "Can not create runnable from TestScript: [#{options[0]}]."
    when :unable_to_locate_runnable
      "Can not locate runnable with id: [#{options[0]}]. Can not execute."
    when :assertion_error
      "ERROR: Unable to process assertion: #{options[0]}"
    when :assertion_exception
      "#{options[0]}"
    when :bad_reference
      "Unable to read contents of reference: [#{options[0]}]. No reference extracted."
    when :bad_request
      "Unable to create a request from operation."
    when :bad_static_fixture_reference
      "Static fixture included unresolvable reference. Can not load fixture. Moving on."
    when :begin_loading_scripts
      start_message_format("LOAD TESTSCRIPTS", options[0])
    when :begin_preprocess
      start_message_format("PREPROCESS", options[0])
    when :begin_postprocess
      start_message_format("POSTPROCESS", options[0])
    when :begin_runnable_execution
      start_message_format("EXECUTE RUNNABLE", options[0])
    when :begin_setup
      start_message_format("SETUP")
    when :begin_teardown
      start_message_format("TEARDOWN")
    when :begin_test
      start_message_format("TEST")
    when :eval_assert_result
      "#{options[0]}"
    when :evaluate_assert
      "EVALUATING ASSERTION"
    when :execute_operation
      "OPERATION EXECUTION"
    when :execute_operation_error
      "Unable to execute operation. ERROR: [#{options[0]}]. [#{options[1]}]"
    when :fail_execution_result
      "Execution of [#{options[0]}] failed with score: [#{options[1]}]."
    when :finish_loading_scripts
      finish_message_format("LOADING SCRIPTS")
    when :finish_preprocess
      finish_message_format("PREPROCESS")
    when :finish_postprocess
      finish_message_format("POSTPROCESS")
    when :finish_runnable_execution
      finish_message_format("EXECUTING RUNNABLE. FINAL EXECUTION SCORE: [#{testreport.score}]")
    when :finish_setup
      finish_message_format("SETUP")
    when :finish_teardown
      finish_message_format("TEARDOWN")
    when :finish_test
      finish_message_format("TEST")
    when :invalid_assert
      "Invalid assert. Can not evaluate."
    when :invalid_dump
      "Validation error: [#{options[0]}]"
    when :invalid_operation
      "Invalid operation. Can not execute."
    when :invalid_request
      "Unable to create a request using operation: [#{options[0]}]. Can not execute."
    when :no_contained_resource
      "Reference [#{options[0]}] refers to a contained resource that does not exist. Moving on."
    when :no_path
      "Unable to extract path from operation."
    when :no_reference
      "Reference element of reference object is nil. Can not get resource from reference."
    when :no_static_fixture_id
      "No ID for static fixture. Can not load."
    when :no_static_fixture_reference
      "No reference for static fixture. Can not load."
    when :no_static_fixture_resource
      "No resource for static fixture. Can not load."
    when :pass_execute_operation
      "Executed Operation: [#{options[0]}]"
    when :pass_execution_result
      "Execution of [#{options[0]}] passed."
    when :unable_to_load_reference
      "Unable to load reference #{"[#{options[0]}] " unless options[0].nil?}from path [#{options[1]}] or fixtures folder. Encountered: [#{options[2]}]."
    when :see_reports
      "See more execution details in the TestReports at: [#{options[0]}]."
    when :uncaught_error
      "Uncaught error: [#{options[0]}]."
    when :unsupported_ref
      "Remote reference: [#{options[0]}] not supported. No reference extracted."
    when :validation_msg
      options[0]
    when :loading_script
      "Loading TestScript from file: [#{options[0]}]. Validating ..."
    else
      "! unknown message type !"
    end
  end
end

def start_message_format(phase, *options)
  "STARTING TO #{phase}" + (options[0] ? ": [#{options[0]}]" : '')
end

def finish_message_format(phase)
  "FINISHED #{phase}."
end