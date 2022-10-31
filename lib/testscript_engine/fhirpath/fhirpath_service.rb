module FHIRPathService
  def service
    @service ||= FHIR::Client.new('https://inferno.healthit.gov/validatorapi')
  end

  def reply
    @validator.reply
  end

  def evaluate(expression, resource)
    path = "/evaluate?path=#{expression}"
    service.send(:post, path, resource.to_json, { 'Content-Type' => 'json' })
    evaluate_reply
  end

  def evaluate_reply
    return false unless client.reply.response[:code].start_with?(2)

    begin
      JSON.parse(reply.response[:body].body)
    rescue
      nil
    end
  end
end