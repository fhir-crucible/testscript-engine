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
      print space
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
    binding.pry
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
    super
    print_out messages(:finish_runnable_execution)
  end

  # < ---- TO REVIEW ---- >
  def client(*args)
    client = super
    format_with_spacing = logger_format
    FHIR.logger.formatter = format_with_spacing
    return client
  end

  def logger_formats
    @logger_formats ||= {}
  end

  def logger_format
    format_with_spacing = logger_formats[space.length]
    unless format_with_spacing
      format_with_spacing = proc do |severity, datetime, progname, msg|
        "#{space}#{space}#{severity}: #{msg}\n"
      end
      logger_formats[space.length] = format_with_spacing
    end
    format_with_spacing
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
    when :begin_loading_scripts
      "STARTING TO LOAD TESTSCRIPTS FROM #{options[0]}"
    when :begin_making_runnables
      "STARTING TO MAKE RUNNABLES"
    when :begin_runnable_execution
      "STARTING TO EXECUTE RUNNABLE: [#{options[0]}]"
    when :cant_deserialize_script
      "Could not deserialize resource: [#{options[0]}]"
    when :cant_make_runnable
      "Could not make runnable from TestScript: [#{options[0]}]"
    when :finish_loading_scripts
      "FINISHED LOADING TESTSCRIPTS."
    when :finish_making_runnables
      "FINISHED MAKING RUNNABLES."
    when :finish_runnable_execution
      "FINIShED EXECUTING RUNNABLE."
    when :invalid_script
      "Could not load resource: [#{options[0]}]"
    when :invalid_dump
      "Validation error: [#{options[0]}]"
    when :loaded_script
      "Loaded TestScript: [#{options[0]}]"
    when :made_runnable
      "Created runnable from TestScript: [#{options[0]}]"
    when :no_runnable_stored
      "No runnable stored with id: [#{options[0]}]. Can not execute."
    when :overwrite_existing_script
      "Overwriting previously loaded TestScript: [#{options[0]}]"






    when :action_assert
      "ASSERT EVALUATION"
    when :action_operation
      "OPERATION EXECUTION"
    when :autocreate
      "INFO: Auto-creating static fixture #{options[0]}."
    when :begin_section
      "BEGIN #{options[0].upcase}"
    when :finish_section
      "FINISH #{options[0].upcase}."
    when :invalid_operation
      "FAIL: Given invalid operation. Can not execute."
    when :invalid_request
      "FAIL: Can not create request given operation. Can not execute."
    when :invalid_script
      "ERROR: Received invalid or non-TestScript resource. Can not create runnable."
    when :execution_error
      "ERROR: Error encountered while executing operation."
    end
  end
end