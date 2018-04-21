module AuthenticateProject
  def authenticate_project
    enforce_hash_with_params('project', params, [:project_id, :accesskey])
    id = params[:project_id]
    accesskey = params[:accesskey]

    website = Website.where(id: id, accesskey: accesskey).first
    raise AuthorizationError.new('Project', id, accesskey) unless website

    website
  end

  def enforce_hash_with_params(hash_name, request_params, keys)
    hash = request_params.to_h

    missing_keys = keys.find_all { |key| not hash.keys.include?(key.to_s) }
    raise InvalidParams.new(hash_name, missing_keys) if missing_keys.any?
  end

  module_function :authenticate_project, :enforce_hash_with_params
end
