# frozen_string_literal: true
module Operation
  class OperationException < StandardError
    attr_reader :details

    def initialize(details)
      @details = details
			super()
    end
  end

  OPERATION_NEEDS_RESOURCE_TYPE = %w[
    put
    patch
    delete
    read
    vread
    update
    create
  ].freeze

  INTERACTION_NEEDS_PAYLOAD = %w[
    patch
    post
    put
  ].freeze

  def execute(operation)
    request = build_request(operation)

    begin
      client.send(*request)
    rescue
      raise OperationException, :bad_request
    end

    storage(operation)
    pass(:pass_execute_operation, operation.label || 'unlabeled')
  end

  def build_request(operation)
    path = get_path(operation)
    headers = get_headers(operation)
    interaction = get_interaction(operation)
    payload = get_payload(operation, interaction)

    [interaction, path, payload, headers].compact
  end

  def get_path(operation)
    return replace_variables(operation.url) if operation.url

    if operation.params
      # [type]/[params]
      "#{get_resource_type(operation)}#{replace_variables(operation.params)}"
    elsif operation.targetId
      resource = get_resource(operation.targetId)
      # TODO: Move this exception into the get_resource method in runnable/utilities
      # just need to make sure that raising this exception is always going to be acceptbale i.e. in any action ever,
      # if the resource isn't available, we should dip
      (raise OperationException, :noResource) unless resource
      path = resource.resourceType
      id = get_id(operation, resource)
      vid = get_vid(operation, resource)
      "#{path}#{id}" + (operation.type&.code == 'history' ? '/_history' : vid)
    elsif operation.sourceId
      resource = get_resource(operation.sourceId)
      raise OperationException, :noResource unless resource

      %w[batch transaction].include?(operation.type&.code) ? '' : resource.resourceType
    else
      raise OperationException, :no_path
    end
  end

  def get_headers(operation)
    headers = {
      'Content-Type' => get_format(operation.contentType),
      'Accept' => get_format(operation.accept)
    }

		operation.requestHeader.each_with_object(headers) do |header|
			headers[header.field] = header.value
		end
	end

  def get_interaction(operation)
    interaction = operation.local_method || operation_to_interaction(operation.type&.code)
    interaction || (raise OperationException, :noInteraction)
  end

  def get_payload(operation, interaction)
    return unless INTERACTION_NEEDS_PAYLOAD.include?(interaction)

    payload = get_resource(operation.sourceId)
    raise OperationException, :noPayload if INTERACTION_NEEDS_PAYLOAD.include?(interaction) && !payload
    payload
  end

  def get_resource_type(operation)
    operation_type = operation.local_method || operation.type.code

    if OPERATION_NEEDS_RESOURCE_TYPE.include?(operation_type) && operation.resource.nil?
      raise OperationException, :noResourceType
    end

    operation.resource
  end

  def get_id(operation, resource)
    id = resource.id
    (raise OperationException, :noId) ['read', 'vread'].include?(operation.type&.code) if id.nil?
    "/#{id}"
  end

  def get_vid(operation, resource)
    vid = resource.meta&.versionId
    if operation.type&.code == 'vread'
      (raise OperationException, :noVid) unless vid
      "/_history/#{vid}"
    else
      ''
    end
  end

  def get_format(format)
    return 'application/fhir+xml' if format == 'xml'

    'application/fhir+json'
  end

  def operation_to_interaction(interaction)
    case interaction
    when 'read', 'vread', 'search', 'search-type', 'search-system', 'capabilities', 'history', 'history-instance', 'history-type', 'history-system', 'operation'
      'get'
    when 'create', 'batch', 'transaction'
      'post'
    when 'update'
      'put'
    when 'patch'
      'patch'
    when 'delete'
      'delete'
    end
  end

  def create_operation(source_id)
    FHIR::TestScript::Setup::Action::Operation.new({
                                                     sourceId: source_id,
                                                     method: 'post'
                                                   })
  end

  def delete_operation(source_id)
    FHIR::TestScript::Setup::Action::Operation.new({
                                                     targetId: id_map[source_id],
                                                     method: 'delete'
                                                   })
  end
end
