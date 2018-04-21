# 	LAST_TAS_COMMAND_CREATE = 1
# 	LAST_TAS_COMMAND_OUTPUT = 2
module NotifyTas
  def retry_cms_request(cms_request, logger = nil)
    logger = Rails.logger unless logger

    message = nil
    # Create project for TP version
    if cms_request.tp_id && cms_request.status == CMS_REQUEST_WAITING_FOR_PROJECT_CREATION && cms_request.last_operation.nil?
      tas_comm = TasComm.new
      tas_comm.create_project(cms_request, logger)
      message = 'Request to create project sent to TAS.'
    # Ask TAS to create project (for wpml 3.1)
    elsif cms_request.last_operation == LAST_TAS_COMMAND_CREATE
      tas_comm = TasComm.new
      @tas_request_notification_sent = true # for testing
      tas_comm.notify_about_request(cms_request, 0, logger)
      message = 'Resent project setup notification'
    # Re send to CMS
    elsif cms_request.last_operation == LAST_TAS_COMMAND_OUTPUT
      number_of_notifications_sent = 0

      notification_sent = false
      cms_request.versions_to_output.each do |version|
        if send_version_notifications(version, version.normal_user, false, nil)
          number_of_notifications_sent += 1
          notification_sent = true
        end
      end

      if notification_sent
        cms_request.following_requests.each do |f_cms_request|
          f_revision = f_cms_request.revision
          sent_for_this = false
          if f_revision
            f_cms_request.versions_to_output.each do |f_version|
              if logger
                logger.info "CMS_REQUEST_FOLLOWING: Checking revision.#{f_revision.id}, version.#{f_version.id}"
              end
              sent_for_this_translator = send_version_notifications(f_version, f_version.normal_user, true, nil)
              logger.info "--- sent: #{sent_for_this_translator}" if logger
              if sent_for_this_translator
                number_of_notifications_sent += 1
                sent_for_this = true
              end
            end
          end
          break unless sent_for_this
        end
      end

      message = 'Sent %d output notifications' % number_of_notifications_sent
    end

    message
  end
  module_function :retry_cms_request

  # TAS output notifications
  def send_output_notification(version, user)
    notification_sent = send_version_notifications(version, user, false, nil)
    if notification_sent
      version.revision.cms_request.following_requests.each do |f_cms_request|
        f_revision = f_cms_request.revision
        sent_for_this = false
        if f_revision
          f_cms_request.versions_to_output.each do |f_version|
            sent_for_this_translator = send_version_notifications(f_version, f_version.normal_user, true, nil)
            sent_for_this = true if sent_for_this_translator
          end
        end
        break unless sent_for_this
      end
    end
  end

  def send_version_notifications(version, translator, force_send_notification, logger = nil)
    # calculate updated statistics for this version
    revision = version.revision
    project = revision.project

    notification_sent = false

    stats = version.get_stats

    stats_txt = ''
    original_lang_id = revision.language_id

    translation_languages_ids = version.translation_languages.collect(&:id)

    translation_languages_ids.each do |language_id|
      next unless language_id != original_lang_id
      if stats && stats.key?(STATISTICS_SENTENCES) && stats[STATISTICS_SENTENCES].key?(language_id)
        stt = stats[STATISTICS_SENTENCES][language_id]
        done_sentences = stt.key?(WORDS_STATUS_DONE_CODE) ? stt[WORDS_STATUS_DONE_CODE] : 0
        total_sentences = 0
        stt.each { |_status, count| total_sentences += count }
      elsif stats && stats.key?(STATISTICS_SENTENCES) && stats[STATISTICS_SENTENCES].key?(original_lang_id)
        done_sentences = 0
        total_sentences = 0
        stt = stats[STATISTICS_SENTENCES][original_lang_id]
        stt.each { |_status, count| total_sentences += count }
      else
        done_sentences = 0
        total_sentences = 0
      end

      begin
        language = Language.find(language_id)
      rescue
        language = nil
        if logger
          logger.info "-------- cannot find language #{language_id} for version #{version.id}"
        end
      end
      previous_cms_items_exist = !force_send_notification && revision.cms_request && !revision.cms_request.previous_requests.empty?
      tas_notification_languages = []
      if language
        stats_txt += if total_sentences != 0
                       "   * #{language.name}: #{(100.0 * done_sentences / total_sentences).to_i}% complete.\n"
                     else
                       "   * #{language.name}: 100% complete.\n"
                     end

        if done_sentences == total_sentences

          # look up the revision language for this job
          rl = RevisionLanguage.where("(language_id=#{language_id}) AND (revision_id=#{revision.id})").first

          # check if this project came from TAS, if so, send TAS the notification and not the client
          unless previous_cms_items_exist
            if revision.cms_request

              cms_target_language = revision.cms_request.cms_target_languages.where('language_id=?', language_id).first
              cms_target_language.update_attributes(delivered: 1, status: CMS_TARGET_LANGUAGE_TRANSLATED)
              uncompleted_language = revision.cms_request.cms_target_languages.where('delivered IS NULL').first
              unless uncompleted_language
                revision.cms_request.update_attributes(delivered: 1, status: CMS_REQUEST_TRANSLATED)
              end

              tas_notification_languages << cms_target_language
            end
          end
        else # not all sentences are translated
          logger.info "Not all sentences translated for #{language.name}: #{done_sentences} / #{total_sentences} complete. Will not send notification\n" if logger
        end
      end
      tas_notification_languages.each do |tas_notification_language|
        if logger
          logger.info "------>>>>> SENDING TAS new version notification for cms_request.#{revision.cms_request.id} to language.#{tas_notification_language.language.name}"
        end
        tas_comm = TasComm.new
        tas_comm.notify_about_translation_completion(revision.cms_request, tas_notification_language.language, version)
        @tas_completion_notification_sent = [] if @tas_completion_notification_sent.nil?
        @tas_completion_notification_sent << "SENDING TAS new version notification for cms_request.#{revision.cms_request.id} to language.#{tas_notification_language.language.name}"
        notification_sent = true
      end
    end

    if !revision.cms_request && project.client.can_receive_emails?
      begin
        ReminderMailer.new_version(project.client, version, translator, stats_txt).deliver_now
      rescue
      end
    end

    notification_sent
  end

end
