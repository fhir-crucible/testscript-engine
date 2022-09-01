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
  end

  def info(message_type, *options)
    print_out messages(message_type, *options)
  end

  def error(message_type, *options)
    return unless debug_mode
    print_out messages(message_type, *options)
  end

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
    print_out messages(:finish_runnable_execution)
    result
  end

  def preprocessing
    print_out messages(:begin_preprocessing)
    super
    print_out messages(:finish_preprocessing)
  end

  def setup
    print_out messages(:begin_setup)
    super
    print_out messages(:finish_setup)
  end

  def test

  end

  def teardown

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

  def pass
    print_out ("SUCCESS!")
  end

  def fail(message_type, *options)
    message = messages(message_type, *options)
    super(message)
    print_out "#{outcome_symbol("FAIL")} #{message}"
  end

  def skip(message_type, *options)
    message = messages(message_type, *options)
    super(message)
    print_out message
  end

  def warning(message_type, *options)
    message = messages(message_type, *options)
    super(message)
    print_out ("WARNING: " + message)
  end

  # TODO: Implement once error support added to TestReportHandler module
  def error(message_type, *options)
    message = messages(message_type, *options)
    super(message)
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
    return client
  end

  def logger_formatters_with_spacing
    @logger_formatters_with_spacing ||= {}
  end

  def logger_formatter_with_spacing
    logger_formatters_with_spacing[space.length] || begin
      new_logger_formatter = proc do |severity, datetime, progname, msg|
        "#{space}#{unit_of_space}#{outcome_symbol(severity)} #{msg}\n"
      end
      logger_formatters_with_spacing[space.length] = new_logger_formatter
      new_logger_formatter
    end
  end

  def outcome_symbol(outcome)
    symbol = begin
      case outcome
      when "INFO"
        [10003].pack("U*")
      when "FAIL"
        [10007].pack("U*")
      end
    end

    "(#{symbol})"
  end




  # < --- Line of Code Review ---> #
  # def begin_section_sign
  #   " ----->"
  # end

  # def end_section_sign
  #   "<----- "
  # end

  # def newline_between_section
  #   true
  # end

  # def newline_within_section
  #   true
  # end

  # def newline_between_actions
  #   true
  # end

  # # TODO: Add in pre and post processing, once flow is cleaned up
  # #
  # # def preprocessing
  # #   output_section_message('preprocessing')
  # # end

  # def setup
  #   output_section_message('setup')
  # end

  # def test
  #   output_section_message('test')
  # end

  # def teardown
  #   output_section_message('teardown')
  # end

  # # def postprocessing
  # #   output_section_message('postprocessing')
  # # end

  # def execute_operation(operation)
  #   if previous_action('operation')
  #     add_spacing
  #     result = super
  #     remove_spacing
  #     result
  #   end
  #   add_spacing
  #   puts messages(:action_operation)
  #   result = super
  #   remove_spacing
  #   result
  # end

  # def evaluate(assert)
  #   return super if previous_action('assert')
  #   add_spacing
  #   puts messages(:action_assert)
  #   result = super
  #   remove_spacing
  #   result
  # end


  # def previous_action(action_type)
  #   return true if @previous_action == action_type

  #   @previous_action = action_type
  #   puts if newline_between_actions
  #   return false
  # end

  # def uncaught_error(error_type)
  #   puts
  #   messages(error_type)
  #   puts
  # end

  # def action_fail(fail_type)
  #   add_spacing
  #   puts messages(fail_type)
  #   remove_spacing
  # end

  # def action_error(error_type)
  #   add_spacing
  #   puts messages(error_type)
  #   remove_spacing
  # end

  # def output_section_message(section_type)
  #   add_spacing
  #   puts messages(:begin_section, section_type)
  #   puts if newline_within_section

  #   result = method(section_type.to_sym).super_method.call

  #   puts if newline_within_section
  #   puts messages(:finish_section, section_type)
  #   remove_spacing
  #   puts if newline_between_section

  #   result
  # end

  def messages(message, *options)
    message_text = case message
    when :assertion_error
      "ERROR: Unable to process assertion: #{options[0]}"
    when :assertion_exception
      "#{options[0]}"
    when :bad_reference
      "Unable to read contents of reference: [#{options[0]}]. No reference extracted."
    when :begin_loading_scripts
      start_message_format("LOAD TESTSCRIPTS", options[0])
    when :begin_making_runnables
      start_message_format("MAKE RUNNABLE(S)")
    when :begin_preprocessing
      start_message_format("PREPROCESS", options[0])
    when :begin_runnable_execution
      start_message_format("EXECUTE RUNNABLE", options[0])
    when :begin_setup
      start_message_format("SETUP")
    when :cant_deserialize_script
      "Could not deserialize resource: [#{options[0]}]"
    when :cant_make_runnable
      "Could not make runnable from TestScript: [#{options[0]}]"
    when :evaluate_assert
      "EVALUATING ASSERTION"
    when :execute_operation
      "OPERATION EXECUTION"
    when :execute_operation_error
      "ERROR: Unable to execute operation: [#{options[0]}]. [#{options[1]}]"
    when :finish_loading_scripts
      finish_message_format("LOADING SCRIPTS")
    when :finish_making_runnables
      finish_message_format("MAKING RUNNABLE(S)")
    when :finish_preprocessing
      finish_message_format("PREPROCESSING")
    when :finish_runnable_execution
      finish_message_format("EXECUTING RUNNABLE")
    when :finish_setup
      finish_message_format("SETUP")
    when :invalid_assert
      "Invalid assert. Can not evaluate."
    when :invalid_dump
      "Validation error: [#{options[0]}]"
    when :invalid_operation
      "Invalid operation. Can not execute."
    when :invalid_request
      "Unable to create a request using operation: [#{options[0]}]. Can not execute."
    when :invalid_script
      "Could not load resource: [#{options[0]}]"
    when :loaded_static_fixture
      "Loaded static fixture: [#{options[0]}]."
    when :loaded_script
      "Loaded TestScript: [#{options[0]}]"
    when :made_runnable
      "Created runnable from TestScript: [#{options[0]}]"
    when :no_runnable_stored
      "No runnable stored with id: [#{options[0]}]. Can not execute."
    when :no_static_fixture_id
      "No ID for static fixture. Can not load."
    when :no_static_fixture_reference
      "No reference for static fixture. Can not load."
    when :no_static_fixture_resource
      "No resource for static fixture. Can not load."
    when :overwrite_existing_script
      "Overwriting previously loaded TestScript: [#{options[0]}]"
    when :unsupported_ref
      "Remote reference: [#{options[0]}] not supported. No reference extracted."






    # when :action_assert
    #   "ASSERT EVALUATION"
    # when :action_operation
    #   "OPERATION EXECUTION"
    # when :autocreate
    #   "INFO: Auto-creating static fixture #{options[0]}."
    # when :begin_section
    #   "BEGIN #{options[0].upcase}"
    # when :finish_section
    #   "FINISH #{options[0].upcase}."
    # when :invalid_operation
    #   "FAIL: Given invalid operation. Can not execute."
    # when :invalid_request
    #   "FAIL: Can not create request given operation. Can not execute."
    # when :invalid_script
    #   "ERROR: Received invalid or non-TestScript resource. Can not create runnable."
    # when :execution_error
    #   "ERROR: Error encountered while executing operation."
    end
  end
end

def start_message_format(phase, *options)
  "STARTING TO #{phase}" + (options[0] ? ": [#{options[0]}]" : '')
end

def finish_message_format(phase)
  "FINISHED #{phase}."
end