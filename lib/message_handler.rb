module MessageHandler
  attr_accessor :debug_mode

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

  # TODO: What's going on here?
  # def error(message_type, *options)
  #   return unless debug_mode
  #   print_out messages(message_type, *options)
  # end

  def load_scripts
    print_out messages(:begin_loading_scripts, root)
    super
    print_out messages(:finish_loading_scripts)
  end

  def make_runnables
    print_out messages(:begin_making_runnables)
    super
    print_out messages(:finish_making_runnables)
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
  end

  def execute_operation(*args)
    print_out messages(:execute_operation) if print_action_header(:operation)
    increase_space
    super
    decrease_space
  end

  def evaluate(*args)
    print_out messages(:evaluate_assert) if print_action_header(:assert)
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
    super(message)
    print_out "#{outcome_symbol("FAIL")} #{message}"
  end

  def skip(message_type, *options)
    message = messages(message_type, *options)
    super(message)
    print_out "#{outcome_symbol("WARN")} #{message}"
  end

  def warning(message_type, *options)
    message = messages(message_type, *options)
    super(message)
    print_out message
  end

  def error(message_type, *options)
    message = messages(message_type, *options)
    super(message) unless [:bad_script, :invalid_script].include?(message_type)
    print_out ("ERROR: " + message)
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
    when :assertion_error
      "ERROR: Unable to process assertion: #{options[0]}"
    when :assertion_exception
      "#{options[0]}"
    when :bad_reference
      "Unable to read contents of reference: [#{options[0]}]. No reference extracted."
    when :bad_script
      "Did not receive TestScript resource as expected. Unable to create runnable."
    when :bad_static_fixture_reference
      "Static fixture included unresolvable reference. Can not load fixture. Moving on."
    when :begin_initialize_client
      start_message_format("INITIALIZE CLIENT(S)")
    when :begin_loading_scripts
      start_message_format("LOAD TESTSCRIPTS", options[0])
    when :begin_making_runnables
      start_message_format("MAKE RUNNABLE(S)")
    when :begin_preprocess
      start_message_format("PREPROCESS", options[0])
    when :begin_runnable_execution
      start_message_format("EXECUTE RUNNABLE", options[0])
    when :begin_setup
      start_message_format("SETUP")
    when :begin_teardown
      start_message_format("TEARDOWN")
    when :begin_test
      start_message_format("TEST")
    when :cant_deserialize_script
      "Could not deserialize resource: [#{options[0]}]"
    when :cant_make_runnable
      "Could not make runnable from TestScript: [#{options[0]}]"
    when :eval_assert_result
      "#{options[0]}"
    when :evaluate_assert
      "EVALUATING ASSERTION"
    when :execute_operation
      "OPERATION EXECUTION"
    when :execute_operation_error
      "Unable to execute operation. ERROR: [#{options[0]}]. [#{options[1]}]"
    when :finish_initialize_client
      finish_message_format("INITIALIZING CLIENT(S)")
    when :finish_loading_scripts
      finish_message_format("LOADING SCRIPTS")
    when :finish_making_runnables
      finish_message_format("MAKING RUNNABLE(S)")
    when :finish_preprocess
      finish_message_format("PREPROCESS")
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
    when :invalid_script
      "Could not load TestScript resource" + (options[0] ? "[#{options[0]}]." : ".")
    when :loaded_static_fixture
      "Loaded static fixture: [#{options[0]}]."
    when :loaded_script
      "Loaded TestScript: [#{options[0]}]"
    when :made_runnable
      "Created runnable from TestScript: [#{options[0]}]"
    when :no_contained_resource
      "Reference [#{options[0]}] refers to a contained resource that does not exist. Moving on."
    when :no_preprocess
      "No preprocess to perform."
    when :no_postprocess
      "No postprocess to perform."
    when :no_reference
      "Reference element of reference object is nil. Can not get resource from reference."
    when :no_runnable_stored
      "No runnable stored with id: [#{options[0]}]. Can not execute."
    when :no_setup
      "No setup to perform."
    when :no_static_fixture_id
      "No ID for static fixture. Can not load."
    when :no_static_fixture_reference
      "No reference for static fixture. Can not load."
    when :no_static_fixture_resource
      "No resource for static fixture. Can not load."
    when :no_teardown
      "No teardown to perform."
    when :overwrite_existing_script
      "Overwriting previously loaded TestScript: [#{options[0]}]"
    when :pass_execute_operation
      "Executed Operation: [#{options[0]}]"
    when :resource_extraction
      "Unable to extract resource referenced by [#{options[0]}]. Encountered: [#{options[1]}]."
    when :unsupported_ref
      "Remote reference: [#{options[0]}] not supported. No reference extracted."
    end
  end
end

def start_message_format(phase, *options)
  "STARTING TO #{phase}" + (options[0] ? ": [#{options[0]}]" : '')
end

def finish_message_format(phase)
  "FINISHED #{phase}."
end