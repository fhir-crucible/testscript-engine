# frozen_string_literal: true

require 'fhir_client'

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#                                                                               #
#                             Validation Module                                 #
#                                                                               #
# The Validation module encapsulates anything related to determining FHIR       #
# resource validity. This includes setting the validator endpoint – which       #
# points to Inferno's validator API by default – and using that endpoint to     #
# confirm if a resource is valid. If the OperationOutcome returned by the       #
# validator endpoint contains an issue with severity 'fatal' or 'error', then   #
# the resource is deemed invalid. Else, it is valid.                            #
#                                                                               #
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

module Validation
  def validator
    @validator ||= FHIR::Client.new('https://inferno.healthit.gov/validatorapi')
  end

  def reply
    @validator.reply
  end

  def change_validator_endpoint(endpoint)
    @validator = FHIR::Client.new(endpoint)
  end

  # Try using the $validate operation first, followed by the `/validate`
  # endpoint, and return whether the response conveys validation errors
  def valid_resource?(resource, *profiles)
    validate_using_operation(resource, profiles)
    validate_using_route(resource, profiles) if reply.response[:code] == '404'
    !validation_errors?
  end

  # Attempt validation using the $validate operation
  def validate_using_operation(resource, profiles = [])
    options = {}
    options.merge!({ profile_uri: profiles }) unless profiles.empty?
    validator.validate(resource, options)
  end

  # This approach is specific to Inferno `/validatorapi`, which allows
  # for validation using the `/validate` endpoint with profiles appended
  def validate_using_route(resource, profiles = [])
    path = '/validate'
    path = "#{path}?profile=#{profiles.shift}" unless profiles.empty?
    path = profiles.inject(path) { |full_path, profile| "#{full_path},#{profile}" }
    validator.send(:post, path, resource, { 'Content-Type' => 'json' })
  end

  # If the response (as OperationOutcome) has an issue with severity
  # fatal or error, then a validation error exists. Else, no errors.
  def validation_errors?
    validation_response.issue.any? { |issue| issue.severity != 'information' || issue.severity != 'warning' }
  end

  # Wrap the response in an FHIR::OperationOutcome object
  def validation_response
    FHIR::OperationOutcome.new(JSON.parse(reply.body))
  rescue StandardError
    FHIR::OperationOutcome.new(
      issue: FHIR::OperationOutcome::Issue.new(
        severity: 'error',
        diagnostics: "Unable to process response from validation endpoint: #{reply.request[:url]}"
      )
    )
  end
end
