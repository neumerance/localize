class ShowExceptions

  def self.rescue_responses
    rescue_responses = Hash.new(:internal_server_error)
    rescue_responses.update('ActionController::RoutingError'             => :not_found,
                            'AbstractController::ActionNotFound'         => :not_found,
                            'ActiveRecord::RecordNotFound'               => :not_found,
                            'ActiveRecord::StaleObjectError'             => :conflict,
                            'ActiveRecord::RecordInvalid'                => :unprocessable_entity,
                            'ActiveRecord::RecordNotSaved'               => :unprocessable_entity,
                            'ActionController::MethodNotAllowed'         => :method_not_allowed,
                            'ActionController::NotImplemented'           => :not_implemented,
                            'ActionController::InvalidAuthenticityToken' => :unprocessable_entity)
    rescue_responses
  end

  def self.rescue_templates
    rescue_templates = Hash.new('diagnostics')
    rescue_templates.update('ActionView::MissingTemplate'         => 'missing_template',
                            'ActionController::RoutingError'      => 'routing_error',
                            'AbstractController::ActionNotFound'  => 'unknown_action',
                            'ActionView::Template::Error'         => 'template_error')
    rescue_templates
  end
end
