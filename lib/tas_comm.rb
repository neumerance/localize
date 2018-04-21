require 'xmlrpc/client'

class TasComm
  def create_session_for_user(user)
    ok = false
    while !ok
      session_num = Digest::MD5.hexdigest(String(rand))
      begin
        user_session = UserSession.new(user_id: user.id,
                                       session_num: session_num,
                                       login_time: Time.now,
                                       long_life: 1)
        # try to enter to the database, an error will pop-up if the session already exists
        ok = user_session.save!
      rescue
      end
    end
    session_num
  end

  def create_project(cms_request, logger)
    logger = Rails.logger unless logger

    session_num = create_session_for_user(cms_request.website.client)
    logger.info(" TAS is creating a project for cms_request: #{cms_request.id}")
    server = get_server(cms_request)
    res = server.call('create_project', cms_request.id, session_num, cms_request.website.id)
  rescue XMLRPC::FaultException => e
    logger.error 'TAS error:'
    logger.error e
    logger.error e.faultCode
    logger.error e.faultString
    logger.error e.backtrace.join("\n")
    logger.error '===================================='
    raise
  end

  # This seems to request TAS to create project for WPML 3.1 ... not checked yet. is called
  # on retry and on CmsRequestController#create
  def notify_about_request(cms_request, tas_command, logger = nil)
    session_num = create_session_for_user(cms_request.website.client)
    server = get_server(cms_request)
    cms_request.update_attributes!(last_operation: LAST_TAS_COMMAND_CREATE, pending_tas: 1, error_description: nil)
    if server
      begin
        res = server.call('queue_cms_request', cms_request.id, session_num, cms_request.website.id, tas_command)
      rescue
      end
    else
      res = 'skipped XML-RPC call'
    end

    logger.info "---- TAS_REQUEST - notify_about_request: #{res}" if logger
    session_num
  end

  def migrate_to_xliff(cms_request, language, version, logger = nil)
    session_num = create_session_for_user(cms_request.website.client)
    server = get_server(cms_request)
    cms_request.update_attributes!(last_operation: LAST_TAS_COMMAND_OUTPUT, pending_tas: 1, error_description: nil)
    if server
      begin
        puts ['generate_xliff', cms_request.id, session_num, cms_request.website_id, language.id, version.revision.project_id, version.revision.id, version.id] rescue puts 'not able to print parameters'
        res = server.call('generate_xliff', cms_request.id, session_num, cms_request.website_id, language.id, version.revision.project_id, version.revision.id, version.id)
      rescue => e
        puts e.faultString
        raise
      end
    else
      res = 'skipped XML-RPC call'
    end

    if logger
      logger.info "---- TAS_REQUEST - notify_about_translation_completion: #{res}"
    end
    session_num
  end

  def notify_about_translation_completion(cms_request, language, version, logger = nil)
    command_id = 123
    session_num = create_session_for_user(cms_request.website.client)
    server = get_server(cms_request)
    cms_request.update_attributes!(last_operation: LAST_TAS_COMMAND_OUTPUT, pending_tas: 1, error_description: nil)
    res = if server
            server.call('html_output', cms_request.id, session_num, cms_request.website_id, language.id, version.revision.project_id, version.revision.id, version.id, command_id)
          else
            'skipped XML-RPC call'
          end

    if logger
      logger.info "---- TAS_REQUEST - notify_about_translation_completion: #{res}"
    end
    session_num
  end

  def get_server(cms_request = nil)
    return nil if Rails.env == 'test'
    tas_url_to_use = TAS_URL
    tas_port_to_use = ENV['TAS_PORT'] || TAS_PORT
    if Rails.env == 'sandbox'
      if cms_request.tas_url == '-'
        return nil
      elsif !cms_request.tas_url.blank?
        tas_url_to_use = cms_request.tas_url
        tas_port_to_use = cms_request.tas_port
      end
    end

    Rails.logger.info "TAS url: #{tas_url_to_use}:#{tas_port_to_use}"

    XMLRPC::Client.new(tas_url_to_use, '/', tas_port_to_use)
  end

  def self.force_flush_queue
    new.get_server.call('force_flush_queue')
  end

  def self.get_queue_size
    new.get_server.call('get_queue_size')
  end
end
