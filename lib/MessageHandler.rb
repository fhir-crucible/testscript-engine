module MessageHandler

  # FORMAT: Simple issue, reason why it is an issue. Optional action. Additional details.
  WARNINGS = {
    'badFixtureReference' => 'Fixture.resource.reference undefined, unable to store fixture. Proceeding to next fixture.',
    'badReference' => 'Unable to read contents of reference. No reference extracted. Given reference:',
    'noFixtureId' => 'Fixture.id undefined, unable to store fixture. Proceeding to next fixture.',
    'noFixtureResource' => 'Fixture.resource undefined, unable to store fixture. Proceeding to next fixture.',
    'unsupportedRef' => 'Remote reference not supported. No reference extracted. Given remote reference:',
    nil => 'Some unexpected behavior occurred with unknown message type.'
  }

  FAILURES = {
    'invalidAssert' => 'assert is not a valid FHIR::TestScript::Setup::Action::Assert type. Asserts must be of valid type.',
    'noClient' => 'Client is undefined, unable to test undefined endpoint.',
    'noId' => 'id_map[operation.targetId] is undefined. The fixture corresponding to operation.targetId must be stored on the target endpoint at a known id.',
    'noResource' => 'operation.resource is undefined. When Operation uses params, resource must also be defined.',
    'noRequestType' => 'Both operation.type.code and operation.method are undefined. Operations must have a valid code type or method.',
    'noSourceFixture' => 'fixtures[operation.sourceId] is undefined. sourceId must correspond to a known fixture.',
    'noSourceFixtureClass' => 'fixtures[operation.sourceId].class is undefined. Fixture corresponding to sourceId must have its class defined.',
    'noSourceId' => 'operation.sourceId is undefined. Sender requests must use sourceId to specify a resource to send.',
    'noTargetFixture' => 'fixtures[operation.targetId] is undefined. targetId must correspond to a known fixture.',
    'unknownFailure' => 'Exact cause of failure unknown.'
  }

  SKIP = {
    'notImplemented' => 'Support for this operation type is not yet implemented.'
  }

  # TODO: Should these be logged onto command-line?

  def failure type
    FAILURES[type]
  end

  def skip type
    SKIP[type]
  end

  def method
    caller[1].split("`").pop.gsub("'", "")
  end

  def log_error message
    FHIR.logger.error "[.#{method}] #{message}"
    return nil
  end

  def warn(type, additional = nil)
    FHIR.logger.warn "[.#{method}] #{WARNINGS[type]} #{additional ? "'#{additional}.'" : ''}"
    return nil
  end
end