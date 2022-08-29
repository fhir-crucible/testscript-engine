module MessageHandler
  def spacing
    @space ||= ""
  end

  def add_spacing
    spacing << space
  end

  def space
    "   "
  end

  def remove_spacing
    @space = spacing[0...-(space.length)]
  end

  def begin_section_sign
    " ----->"
  end

  def end_section_sign
    "<----- "
  end

  def newline_between_section
    true
  end

  def newline_within_section
    true
  end

  def setup
    output_section_message('setup')
  end

  def test
    output_section_message('test')
  end

  def teardown
    output_section_message('teardown')
  end

  def execute_operation(operation)
    if previous_action('operation')
      add_spacing
      result = super
      remove_spacing
      result
    end
    add_spacing
    puts messages(:action_operation)
    result = super
    remove_spacing
    result
  end

  def evaluate(assert)
    return super if previous_action('assert')
    add_spacing
    puts messages(:action_assert)
    result = super
    remove_spacing
    result
  end

  def logger_formats
    @logger_formats ||= {}
  end

  def client(*args)
    client = super
    format_with_spacing = logger_format
    FHIR.logger.formatter = format_with_spacing
    return client
  end

  def logger_format
    format_with_spacing = logger_formats[spacing.length]
    unless format_with_spacing
      format_with_spacing = proc do |severity, datetime, progname, msg|
        "#{spacing}#{space}#{severity}: #{msg}\n"
      end
      logger_formats[spacing.length] = format_with_spacing
    end
    format_with_spacing
  end

  def previous_action(action_type)
    return true if @previous_action == action_type

    @previous_action = action_type
    return false
  end

  def action_fail(fail_type)
    add_spacing
    puts messages(fail_type)
    remove_spacing
  end

  def action_error(error_type)
    add_spacing
    puts messages(error_type)
    remove_spacing
  end

  def output_section_message(section_type)
    add_spacing
    puts messages(:begin_section, section_type)
    puts if newline_within_section

    result = method(section_type.to_sym).super_method.call

    puts if newline_within_section
    puts messages(:finish_section, section_type)
    remove_spacing
    puts if newline_between_section

    result
  end

  def messages(message, *options)
    message_text = case message
    when :action_assert
      "ASSERT EVALUATION"
    when :action_operation
      "OPERATION EXECUTION"
    when :begin_section
      "BEGIN #{options[0].upcase}"
    when :finish_section
      "FINISHED #{options[0].upcase}."
    when :invalid_operation
      "FAIL: Given invalid operation. Can not execute."
    when :invalid_request
      "FAIL: Can not create request given operation. Can not execute."
    when :execution_error
      "ERROR: Error encountered while executing operation."
    end

    if message.start_with? "begin"
      message_text.concat(begin_section_sign)
    elsif message.start_with? "finish"
      message_text.prepend(end_section_sign)
    end

    message_text.prepend(spacing)
  end

  # Runnable
    # Get caller function
    # Log error
    # Log info
      # maybe just log when starting new phase? Also log when phase over, use caller function
        # phase_message

end