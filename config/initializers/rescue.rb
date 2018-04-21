ActionController::Rescue.module_eval do
  def force_local_request
    false
  end
  alias_method :local_request?, :force_local_request
end
