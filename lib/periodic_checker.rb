class PeriodicChecker

  include ChatFunctions
  include NotifyTas

  attr_reader :curtime
  attr_writer :curtime

  def initialize(curtime, logger = nil)
    @curtime = curtime
    @logger = logger
    @basetime = Time.zone.now
  end

  def revisions_open_to_bids_check
    revisions =
      Revision.
      where("(revisions.alert_status != #{REVISION_BIDDING_CLOSED_ALERT}) AND
            (revisions.released = 1) AND
            (UNIX_TIMESTAMP(revisions.bidding_close_time) < #{@curtime.to_i}) AND
            EXISTS (
            SELECT rl.id from revision_languages rl WHERE (rl.revision_id = revisions.id) AND NOT EXISTS (
            SELECT b.id FROM bids b
            WHERE (b.revision_language_id = rl.id) AND (b.won = 1)))").
      includes(:project)

    # fill the revision owners in the cache
    Client.find_by(id: revisions.collect { |revision| revision.project.client_id }.uniq)

    revisions.each do |revision|
      event = EVENT_BIDDING_ON_REVISION_CLOSED
      to_who = revision.project.client
      create_reminder_to_object(revision, [revision.project.client], EVENT_BIDDING_ON_REVISION_CLOSED, REVISION_BIDDING_CLOSED_ALERT)
    end
  end

  def clean_old_sessions
    session_timeout_limit = @curtime.to_i - SESSION_TIMEOUT
    tas_timeout_limit = @curtime.to_i - TAS_TIMEOUT

    user_sessions =
      UserSession.
      where("((UNIX_TIMESTAMP(user_sessions.login_time) < #{session_timeout_limit}) AND (user_sessions.long_life IS NULL))
              OR (UNIX_TIMESTAMP(user_sessions.login_time) < #{tas_timeout_limit})")

    user_sessions.delete_all

    SessionTrack.where('NOT EXISTS (SELECT * FROM user_sessions WHERE (user_sessions.id = session_tracks.user_session_id))').delete_all

    ActiveRecord::SessionStore::Session.where("UNIX_TIMESTAMP(updated_at) < #{@curtime.to_i - TAS_TIMEOUT}").delete_all
  end

  def clean_old_captchas
    begin
      CaptchaImage.where("UNIX_TIMESTAMP(create_time) < #{@curtime.to_i - 10 * 60}").destroy_all
    rescue Errno::ENOENT
      # Ignore deletion of unexisting file
    end
    CaptchaImage.where("UNIX_TIMESTAMP(create_time) < #{@curtime.to_i - 10 * 60}").delete_all
  end

  def clean_old_temp_downloads
    TempDownload.where("UNIX_TIMESTAMP(created_at) < #{@curtime.to_i - 30 * 60}").destroy_all
  end

  def work_needs_to_end_check
    democlient = Client.where('email=?', DEMO_CLIENT_EMAIL).first

    # find bids that need to go to automatic arbitration
    Bid.where("(bids.status=#{BID_ACCEPTED}) AND (UNIX_TIMESTAMP(bids.expiration_time) < #{@curtime.to_i - DAY_IN_SECONDS * DAYS_TO_PUT_BID_IN_ARBITRATION}) AND (bids.alert_status < #{BID_WENT_TO_ARBITRATION}) AND (bids.amount > 0) AND NOT EXISTS (SELECT * FROM arbitrations WHERE ((arbitrations.object_id=bids.id) AND (arbitrations.object_type='Bid')))").
      includes(:chat).each do |bid|
      next unless bid.chat.revision.project.client != democlient
      arbitration = Arbitration.new(type_code: SUPPORTER_ARBITRATION_WORK_MUST_COMPLETE,
                                    object_id: bid.id,
                                    object_type: 'Bid',
                                    initiator_id: bid.chat.translator_id,
                                    against_id: bid.chat.revision.project.client_id,
                                    status: ARBITRATION_CREATED)
      create_reminder_to_object(bid, [bid.chat.translator, bid.chat.revision.project.client], EVENT_BID_WENT_TO_ARBITRATION, BID_WENT_TO_ARBITRATION) do
        arbitration.save!
      end
    end

    # find bids that needed to complete a week ago
    Bid.where("(bids.status=#{BID_ACCEPTED}) AND (UNIX_TIMESTAMP(bids.expiration_time) < #{@curtime.to_i - DAY_IN_SECONDS * DAYS_TO_SEND_WORK_COMPLETION_ALERT}) AND (bids.alert_status < #{BID_ABOUT_TO_GO_TO_ARBITRATION}) AND NOT EXISTS (SELECT * FROM arbitrations WHERE ((arbitrations.object_id=bids.id) AND (arbitrations.object_type='Bid')))").
      includes(:chat).each do |bid|
      if bid.chat.revision.project.client != democlient
        create_reminder_to_object(bid, [bid.chat.translator, bid.chat.revision.project.client], EVENT_BID_ABOUT_TO_GO_TO_ARBITRATION, BID_ABOUT_TO_GO_TO_ARBITRATION)
      end
    end

    # find bids that need to complete right now
    Bid.where("(bids.status=#{BID_ACCEPTED}) AND (UNIX_TIMESTAMP(bids.expiration_time) < #{@curtime.to_i}) AND (bids.alert_status < #{BID_NEEDS_TO_COMPLETE}) AND NOT EXISTS (SELECT * FROM arbitrations WHERE ((arbitrations.object_id=bids.id) AND (arbitrations.object_type='Bid')))").
      includes(:chat).each do |bid|
      if bid.chat.revision.project.client != democlient
        create_reminder_to_object(bid, [bid.chat.translator, bid.chat.revision.project.client], EVENT_WORK_NEEDS_TO_COMPLETE, BID_NEEDS_TO_COMPLETE)
      end
    end

  end

  def send_offering_logos(log)
    puts 'sending offering logos'
    count = 0
    Client.joins(:money_accounts).where('sent_logo = ? and userstatus != ? and money_accounts.balance > 0', false, USER_STATUS_CLOSED).each do |client|
      next unless client.has_completed_projects?
      begin
        log += "Sending logo for client #{client.id}"
        if client.can_receive_emails?
          ReminderMailer.offering_logo(client).deliver_now
        end
        count += 1
        client.update_attributes(sent_logo: true)
      rescue => e
        log += 'ERROR: ' + e.inspect
      end
    end
    count
  end

  def new_revisions_mailer
    revisions =
      Revision.
      where("(revisions.released = 1) AND (UNIX_TIMESTAMP(revisions.release_date) > #{@curtime.to_i - DAY_IN_SECONDS + 1})").
      includes(:project)

    # fill the revision owners in the cache
    Client.find_by(id: revisions.collect { |revision| revision.project.client_id }.uniq)

    # create the projects summary body, this will be replicated in every email
    txt = ''
    revisions.each do |revision|
      txt += revision.project.name + ": #{revision.language.name} to #{revision.languages.join(',')}\n"
      txt += "Word count: #{revision.word_count}, maximal bid: #{revision.max_bid} #{revision.currency.name} / word.\n"
      unless revision.categories.empty?
        txt += "Required fields of expertise: #{revision.categories.join(',')}\n"
      end
      txt += "http://www.icanlocalize.com/projects/#{revision.project_id}/revisions/#{revision.id}\n\n"
    end
    logger.info txt
  end

  def send_follow_up_emails
    month_ago = Time.zone.now - 1.month
    target_clients =
      Client.where(
        "((follow_up_email = 0) OR (follow_up_email IS NULL)) AND (created_at < ?) AND (userstatus = ?) AND NOT (
        EXISTS(SELECT * FROM projects WHERE client_id = users.id ) OR
        EXISTS(SELECT * FROM websites WHERE client_id = users.id ) OR
        EXISTS(SELECT * FROM text_resources WHERE client_id = users.id ) OR
        EXISTS(SELECT * FROM web_messages WHERE owner_id = users.id AND owner_type = 'User' ))",
        month_ago, USER_STATUS_CLOSED
      )

    failed_to_deliver = []
    sent_emails = 0
    target_clients.each do |client|
      begin
        if client.can_receive_emails?
          ReminderMailer.follow_up_inactive_client(client).deliver_now
        end
        sent_email += 1
      rescue
        failed_to_deliver << client
      end
    end

    delivered_successful = target_clients.map(&:id) - failed_to_deliver
    unless delivered_successful.empty?
      Client.where("id IN (#{delivered_successful.join(',')})").update_all(follow_up_email: true)
    end

    sent_emails
  end

  def per_profile_mailer(_logger = nil, profile = false, need_translators = false)

    month_ago = Time.zone.now - 1.month
    last_ta_download = Download.order('id DESC').where('(generic_name=?) AND (usertype=?)', TA_GENERIC_NAME, 'Translator').first
    sent_mail_count = 0

    # go through each project type and create lists of jobs to send to each translator
    translator_notifications = {}

    # ---------------------- Bidding projects ----------------------

    scanned_revisions =
      Revision.
      includes(:revision_languages).
      where('(revisions.notified=?) AND (revision_languages.language_id IS NOT NULL) AND (cms_request_id IS NULL)', 0).
      references(:revision_languages)

    total_cnt = scanned_revisions.count
    idx = 1

    # puts "===== got #{revisions.length} revisions => #{revisions.collect { |r| r.id }.join(',')}"

    scanned_revisions.each do |revision|

      # puts "Testing revision.#{revision.id} - #{revision.project.name} - #{idx} / #{total_cnt}"
      idx += 1

      user_status = (revision.kind == TA_PROJECT ? [USER_STATUS_QUALIFIED] : [USER_STATUS_REGISTERED, USER_STATUS_QUALIFIED]).join(',')
      target_lang_id = revision.revision_languages.collect(&:language_id).join(',')

      cond_str = "(users.userstatus IN (#{user_status}))
              AND ((users.notifications & #{DAILY_RELEVANT_PROJECTS_NOTIFICATION}) = #{DAILY_RELEVANT_PROJECTS_NOTIFICATION})
              AND (translator_languages.status = #{TRANSLATOR_LANGUAGE_APPROVED})
              AND (translator_languages.language_id = #{revision.language_id})
              AND (translator_language_tos_users.status = #{TRANSLATOR_LANGUAGE_APPROVED})
              AND (translator_language_tos_users.language_id IN (#{target_lang_id}))"

      if revision.revision_categories.count > 0
        cat_ids = revision.revision_categories.collect(&:category_id).join(',')
        cond_str += " AND (translator_categories.category_id IN (#{cat_ids}))"
      end

      join_tables = [:translator_categories, :translator_language_froms, :translator_language_tos]

      translators =
        Translator.
        includes(*join_tables).
        where(cond_str).
        references(*join_tables)

      translator_ids = translators.pluck(:id)

      notified_translator_ids = {}
      SentNotification.where('(user_id IN (?)) AND (owner_type = ?) AND (owner_id = ?)', translator_ids, 'Revision', revision.id).each { |notification| notified_translator_ids[notification.user_id] = true }

      translators.each do |translator|
        unless notified_translator_ids.key?(translator.id)
          add_notification_to_translator(translator, translator_notifications, 'revisions', revision)
        end
      end

    end

    idx = 1

    # -------------- web messages (instant translation) ---------------

    scanned_web_messages =
      WebMessage.joins(:money_account).
      where(
        '(translation_status = ?) AND (notified = ?) AND (create_time > ?)
        AND (money_accounts.balance >= (web_messages.word_count * ?))',
        TRANSLATION_NEEDED,
        0,
        month_ago,
        INSTANT_TRANSLATION_COST_PER_WORD
      )

    scanned_web_messages.each do |web_message|

      # puts "Testing web_message.#{web_message.id} - #{idx}"
      idx += 1

      if web_message.user_id
        from_lang_id = web_message.client_language_id
        to_lang_id = web_message.visitor_language_id
      else
        from_lang_id = web_message.visitor_language_id
        to_lang_id = web_message.client_language_id
      end

      cond_str = "(users.userstatus IN (#{[USER_STATUS_REGISTERED, USER_STATUS_QUALIFIED].join(',')}))
              AND ((users.notifications & #{DAILY_RELEVANT_PROJECTS_NOTIFICATION}) = #{DAILY_RELEVANT_PROJECTS_NOTIFICATION})
              AND (translator_languages.status = #{TRANSLATOR_LANGUAGE_APPROVED})
              AND (translator_languages.language_id = #{from_lang_id})
              AND (translator_language_tos_users.status = #{TRANSLATOR_LANGUAGE_APPROVED})
              AND (translator_language_tos_users.language_id = #{to_lang_id})"

      translators = Translator.joins(:translator_language_froms, :translator_language_tos).where(cond_str)

      translator_ids = translators.collect(&:id)

      notified_translator_ids = {}
      SentNotification.where('(user_id IN (?)) AND (owner_type = ?) AND (owner_id = ?)', translator_ids, 'WebMessage', web_message.id).each { |notification| notified_translator_ids[notification.user_id] = true }

      translators.each do |translator|
        unless notified_translator_ids.key?(translator.id)
          add_notification_to_translator(translator, translator_notifications, 'web_messages', web_message)
        end
      end

    end

    # --------------- open_website_translation_work ------------------
    # New CmsRequests from language pairs where the translator is already
    # assigned to (from the specific websites that have assigned the translator).
    # He can (and should) get started with the translation immediately.

    website_contracts = {}
    scanned_cms_requests = []

    # CmsRequests that are paid for, have at least one translator assigned to
    # their language pair, are not yet taken by a translator (none of the
    # translator assigned to the language pair clicked "Start Translation" for
    # this Cmsrequest yet) and not mentioned in any previous notification e-mails.
    open_cms_requests_sql = <<-SQL
      SELECT DISTINCT cms_requests.*
      FROM cms_requests
        JOIN cms_target_languages AS ctl
          ON cms_requests.id = ctl.cms_request_id
        -- translation job must be paid
        INNER JOIN pending_money_transactions AS pmt
          ON cms_requests.id = pmt.owner_id
             AND pmt.owner_type = 'CmsRequest'
        /* joining websites and website_translation_offers is required in order to
        join website_translation_contracts */
        JOIN websites
          ON websites.id = cms_requests.website_id
        JOIN website_translation_offers AS wto
         ON wto.from_language_id = cms_requests.language_id
             AND wto.to_language_id = ctl.language_id
             AND wto.website_id = websites.id
        /* language pair of the cms_request must have at least 1 assigned translator,
        otherwise there will be no one to notify */
        INNER JOIN website_translation_contracts AS wtc
          ON wtc.website_translation_offer_id = wto.id
             AND wtc.status = #{TRANSLATION_CONTRACT_ACCEPTED}
      WHERE cms_requests.status = #{CMS_REQUEST_RELEASED_TO_TRANSLATORS}
            AND ctl.status = #{CMS_TARGET_LANGUAGE_CREATED}
            AND cms_requests.notified = 0
    SQL

    open_cms_requests = CmsRequest.find_by_sql(open_cms_requests_sql)

    open_cms_requests.each do |cms_request|
      # find all the translators with accepted applications
      from_language_id = cms_request.language_id
      to_language_id = cms_request.cms_target_languages[0].language_id

      # A translator can be assigned to a language pair
      # (WebsiteTranslationOffer) which has many new CmsRequests, so the
      # WebsiteTranslationContract is cached to reduce the number of queries.
      # We can refactor this by expanding the above query to also retrieve the
      # translators associated with accepted WTCs.
      key = [cms_request.website_id, from_language_id, to_language_id]
      if website_contracts.key?(key)
        # Accepted contracts for this website and language pair are already
        # memoized. Fetch from memory.
        contracts = website_contracts[key]
      else
        offer = cms_request.website_translation_offer
        if offer
          contracts = offer.accepted_website_translation_contracts
          # Memoize
          website_contracts[key] = contracts
        else
          contracts = []
        end
      end

      contracts.each do |contract|
        add_notification_to_translator(contract.translator, translator_notifications, 'cms_requests', cms_request)
      end

      scanned_cms_requests << cms_request
    end # end of loop

    idx = 1

    # -------------- website translation offers ---------------
    # Language pairs that are available for translators to apply (without the
    # need to be invited by the client). Note that having one accepted translator
    # is not a criterion to exclude a language pair from this list. The client
    # may want to assign multiple translators to a single language pair.

    scanned_website_translation_offers =
      WebsiteTranslationOffer.
      joins(:website).
      where(
        '(websites.project_kind != ?)
        AND (websites.anon != 1)
        AND (website_translation_offers.status=?)
        AND (website_translation_offers.notified = ?)
        AND (website_translation_offers.updated_at IS NULL OR (website_translation_offers.updated_at > ?))
        AND (website_translation_offers.automatic_translator_assignment = ?)',
        TEST_CMS_WEBSITE,
        TRANSLATION_OFFER_OPEN,
        0,
        month_ago,
        0
      )

    scanned_website_translation_offers.each do |website_translation_offer|
      idx += 1

      # Only notify translators about language pairs that have at least one
      # paid CmsRequest. Many people send contents and never pay, let's not
      # waste the translators' time with that.
      # TODO: incorporate this in the above query to avoid N+1
      next unless website_translation_offer.cms_requests.any?(&:paid?)

      cond_str = "(users.userstatus = #{USER_STATUS_QUALIFIED})
              AND ((users.notifications & #{DAILY_RELEVANT_PROJECTS_NOTIFICATION}) = #{DAILY_RELEVANT_PROJECTS_NOTIFICATION})
              AND (translator_languages.status = #{TRANSLATOR_LANGUAGE_APPROVED})
              AND (translator_languages.language_id = #{website_translation_offer.from_language_id})
              AND (translator_language_tos_users.status = #{TRANSLATOR_LANGUAGE_APPROVED})
              AND (translator_language_tos_users.language_id = #{website_translation_offer.to_language_id})"

      translators = Translator.joins(:translator_language_froms, :translator_language_tos).where(cond_str)

      translator_ids = translators.collect(&:id)

      notified_translator_ids = {}
      SentNotification.where('(user_id IN (?)) AND (owner_type = ?) AND (owner_id = ?)', translator_ids, 'WebsiteTranslationOffer', website_translation_offer.id).each { |notification| notified_translator_ids[notification.user_id] = true }

      translators.each do |translator|
        unless notified_translator_ids.key?(translator.id)
          add_notification_to_translator(translator, translator_notifications, 'website_translation_offers', website_translation_offer)
        end
      end
    end

    idx = 1

    # --------------- text resources (software translation) -------------------

    scanned_resource_languages = []
    text_resources =
      TextResource.
      joins(:resource_languages, :resource_strings).
      where(
        '(resource_languages.status = ?) AND
        (resource_languages.notified = ?) AND
        (resource_languages.updated_at IS NULL OR
        (resource_languages.updated_at > ?)) AND (resource_strings.id IS NOT NULL)',
        RESOURCE_LANGUAGE_OPEN,
        0,
        month_ago
      ).distinct

    text_resources.each do |text_resource|
      text_resource.resource_languages.each do |resource_language|
        next unless resource_language.notified == 0

        # puts "Testing resource_language.#{resource_language.id} - #{idx}"
        idx += 1

        cond_str = "(users.userstatus IN (#{[USER_STATUS_REGISTERED, USER_STATUS_QUALIFIED].join(',')}))
                AND ((users.notifications & #{DAILY_RELEVANT_PROJECTS_NOTIFICATION}) = #{DAILY_RELEVANT_PROJECTS_NOTIFICATION})
                AND (translator_languages.status = #{TRANSLATOR_LANGUAGE_APPROVED})
                AND (translator_languages.language_id = #{text_resource.language_id})
                AND (translator_language_tos_users.status = #{TRANSLATOR_LANGUAGE_APPROVED})
                AND (translator_language_tos_users.language_id = #{resource_language.language_id})"

        translators = Translator.joins(:translator_language_froms, :translator_language_tos).where(cond_str)

        translator_ids = translators.collect(&:id)

        notified_translator_ids = {}

        SentNotification.
          where('(user_id IN (?)) AND (owner_type = ?) AND (owner_id = ?)',
                translator_ids,
                'ResourceLanguage',
                resource_language.id).
          each { |notification| notified_translator_ids[notification.user_id] = true }

        translators.each do |translator|
          unless notified_translator_ids.key?(translator.id)
            add_notification_to_translator(translator, translator_notifications, 'resource_languages', resource_language)
          end
        end

        scanned_resource_languages << resource_language

      end
    end

    # ---------- managed works (review jobs) ------------
    idx = 1

    # puts "-------- looking for open managed works (month_ago = #{month_ago})"
    scanned_managed_works = ManagedWork.joins(:client).
                            where('(managed_works.active = ?) AND (managed_works.notified = ?) AND (managed_works.updated_at IS NULL OR (managed_works.updated_at > ?)) AND (users.id IS NOT NULL) AND (managed_works.translator_id IS NULL) ',
                                  MANAGED_WORK_ACTIVE, 0, month_ago)

    # puts "------- checking managed_works. Found #{managed_works.length}"
    scanned_managed_works.each do |managed_work|

      # puts "Testing managed_work.#{managed_work.id} - #{idx}"
      idx += 1

      # Each software translation project has only one source (from) language
      # and may have multiple target (to) languages.
      # Each ManagedWork has only one source and one target language.
      # The same person cannot be both the translator and the reviewer of the
      # same target language in a project, or else he would be reviewing his
      # own work.
      # In conclusion, the e-mail sent to the person that translated a target
      # language for this project should not contain a ManagedWork related to
      # the same project, with the same target language.
      review_target_language = managed_work.to_language
      # ID of the software project translator for the target language that
      # requires review.
      # NoMethodError may happen in more than one place, specially in legacy
      # integration tests which call this method without providing all
      # dependencies for the managed_work object.
      target_language_translator_id = begin
                                        managed_work.
                                          owner.
                                          resource_languages.
                                          where(language: review_target_language).
                                          first.
                                          selected_chat.
                                          translator_id
                                      rescue NoMethodError
                                        nil
                                      end

      cond_str = "(users.userstatus = #{USER_STATUS_QUALIFIED})
                 AND ((users.notifications & #{DAILY_RELEVANT_PROJECTS_NOTIFICATION}) = #{DAILY_RELEVANT_PROJECTS_NOTIFICATION})
                 AND (users.level = #{EXPERT_TRANSLATOR})
                 AND (translator_languages.status = #{TRANSLATOR_LANGUAGE_APPROVED})
                 AND (translator_languages.language_id = #{managed_work.from_language_id})
                 AND (translator_language_tos_users.status = #{TRANSLATOR_LANGUAGE_APPROVED})
                 AND (translator_language_tos_users.language_id = #{managed_work.to_language_id})"

      cond_str += "AND (users.id != #{target_language_translator_id})" if target_language_translator_id

      translators = Translator.joins(:translator_language_froms,
                                     :translator_language_tos).where(cond_str)

      translator_ids = translators.collect(&:id)

      notified_translator_ids = {}
      SentNotification.where('(user_id IN (?)) AND (owner_type = ?) AND (owner_id = ?)', translator_ids, 'ManagedWork', managed_work.id).each { |notification| notified_translator_ids[notification.user_id] = true }
      # puts "notified_translator_ids=#{notified_translator_ids.keys.join(',')}"

      translators.each do |translator|
        unless notified_translator_ids.key?(translator.id)
          add_notification_to_translator(translator, translator_notifications, 'managed_works', managed_work)
        end
      end

    end

    translator_notifications.each do |translator, notifications|
      revisions = notifications['revisions']
      web_messages = notifications['web_messages']
      messages_to_review = []
      open_website_translation_offers = notifications['website_translation_offers']
      open_cms_requests = notifications['cms_requests']
      open_text_resource_projects = notifications['resource_languages']
      open_managed_works = notifications['managed_works']

      if !profile && (!revisions.empty? || !web_messages.empty? || !messages_to_review.empty? ||
        !open_website_translation_offers.empty? || !open_cms_requests.empty? ||
        !open_text_resource_projects.empty? ||
        !open_managed_works.empty?)
        recent_user_ta_download =
          translator.downloads.
          where('downloads.generic_name=?', TA_GENERIC_NAME).
          order('downloads.id DESC').
          first

        download_needed = !(recent_user_ta_download && recent_user_ta_download.id == last_ta_download.id)

        unless open_cms_requests.empty?
          begin
            if translator.can_receive_emails?
              ReminderMailer.new_projects_for_translator('New contents available from your current projects', translator, [], [], [], open_website_translation_offers, open_cms_requests, [], [], download_needed).deliver_now
              sent_mail_count += 1
            end
          rescue
          end
        end

        if !revisions.empty? ||
           !web_messages.empty? ||
           !messages_to_review.empty? ||
           !open_text_resource_projects.empty? ||
           !open_managed_works.empty? ||
           !open_website_translation_offers.empty?

          begin
            if translator.can_receive_emails?
              ReminderMailer.new_projects_for_translator('New projects matching your profile', translator, revisions, web_messages, messages_to_review, [], [], open_text_resource_projects, open_managed_works, download_needed).deliver_now
              sent_mail_count += 1
            end
          rescue
          end
        end

        # record the sent notifications
        add_notifications_to_translator(translator, open_text_resource_projects + open_website_translation_offers + open_cms_requests + open_managed_works + revisions)
      end
    end

    # TODO: there is no need to loop, just use #update_all
    unless profile
      # indicate we're done handling
      Revision.transaction do
        scanned_revisions.each do |revision|
          revision.reload
          revision.update_attributes(notified: 1)
        end
      end

      WebMessage.transaction do
        scanned_web_messages.each do |web_message|
          web_message.reload
          web_message.update_attributes(notified: 1)
        end
      end

      CmsRequest.transaction do
        scanned_cms_requests.each do |cms_request|
          cms_request.reload
          cms_request.update_attributes(notified: 1)
        end
      end

      ResourceLanguage.transaction do
        scanned_resource_languages.each do |resource_language|
          resource_language.reload
          resource_language.update_attributes(notified: 1)
        end
      end

      WebsiteTranslationOffer.transaction do
        scanned_website_translation_offers.each do |website_translation_offer|
          website_translation_offer.reload
          website_translation_offer.update_attributes(notified: 1)
        end
      end

      ManagedWork.transaction do
        scanned_managed_works.each do |managed_work|
          managed_work.reload
          managed_work.update_attributes(notified: 1)
        end
      end
    end

    if need_translators
      return sent_mail_count, translator_notifications
    else
      return sent_mail_count
    end
  end

  def add_notification_to_translator(translator, translator_notifications, project_type, project)
    unless translator_notifications.key?(translator)
      translator_notifications[translator] = { 'revisions' => [], 'web_messages' => [], 'website_translation_offers' => [], 'cms_requests' => [], 'resource_languages' => [], 'managed_works' => [] }
    end
    translator_notifications[translator][project_type] << project
  end

  def account_setup_reminder
    # filter out projects by the demo client
    cnt = 0
    Translator.where("((users.sent_messages & #{USER_MESSAGE_COMPLETE_YOUR_ACCOUNT_SETUP}) = 0)
                      AND ((users.signup_date IS NULL) OR (UNIX_TIMESTAMP(users.signup_date) < #{Time.zone.now.to_i - 4 * DAY_IN_SECONDS}))
                      AND (users.userstatus != #{USER_STATUS_CLOSED})").each do |translator|
      active_items, todos = translator.todos(TODO_STATUS_MISSING)
      if active_items > 0
        missing_items_txt = ''
        todos.each do |todo|
          if todo[0] == TODO_STATUS_MISSING
            missing_items_txt += " * #{todo[1]}\n"
          end
        end
        begin
          if translator.can_receive_emails?
            ReminderMailer.account_setup_reminder(translator, missing_items_txt).deliver_now
          end
        rescue
        end
        cnt += 1
      end
      translator.sent_messages |= USER_MESSAGE_COMPLETE_YOUR_ACCOUNT_SETUP
      translator.save!
    end
    cnt
  end

  def ready_translator_accounts
    translators = Translator.where("((users.sent_messages & #{USER_MESSAGE_ACCOUNT_SETUP_COMPLETE}) = 0)
    AND (users.userstatus = #{USER_STATUS_QUALIFIED})
    AND EXISTS(SELECT * FROM translator_languages to_lang WHERE ((to_lang.type = 'TranslatorLanguageFrom') AND (to_lang.translator_id = users.id) AND (to_lang.status = #{TRANSLATOR_LANGUAGE_APPROVED})))
    AND EXISTS( SELECT * FROM translator_languages from_lang WHERE ((from_lang.type = 'TranslatorLanguageTo') AND (from_lang.translator_id = users.id) AND (from_lang.status = #{TRANSLATOR_LANGUAGE_APPROVED})))
    AND EXISTS( SELECT * FROM identity_verifications id_ver WHERE ((id_ver.normal_user_id = users.id) AND (id_ver.status = #{VERIFICATION_OK})))")
    translators.each do |translator|
      revisions = translator.open_revisions_filtered(true, false)
      send_notification = (translator.notifications & DAILY_RELEVANT_PROJECTS_NOTIFICATION) != 0
      begin
        if translator.can_receive_emails?
          ReminderMailer.account_setup_done(translator, revisions, send_notification).deliver_now
        end
      rescue
      end
      translator.sent_messages |= USER_MESSAGE_ACCOUNT_SETUP_COMPLETE
      translator.save!
    end
    translators.length
  end

  def release_old_instant_messages
    WebMessage.release_old_holds(@curtime)
  end

  def send_newsletters
    sent = 0
    # see if there are pending newsletters
    pending_newsletters = Newsletter.where('(flags & ?) = ?', ALL_PENDING_NEWSLETTERS_MASK, ALL_PENDING_NEWSLETTERS)
    puts pending_newsletters.inspect

    unless pending_newsletters.empty?
      pending_newsletters.each do |newsletter|
        interested_users = newsletter.target_users
        next if interested_users.empty?
        interested_users.each do |user|
          begin
            if user.can_receive_emails?
              ReminderMailer.newsletter(user, newsletter).deliver_now
              sent += 1
            end
          rescue
          end
        end
        newsletter.update_attributes!(flags: newsletter.flags | NEWSLETTER_SENT)
      end
    end

    sent
  end

  def remind_about_instant_messages
    # search for the latest Translation Assistant version for translators
    cnt = 0

    four_hours = (4 * 60 * 60).to_i
    translators = Translator.where("((notifications & #{DAILY_RELEVANT_PROJECTS_NOTIFICATION}) = #{DAILY_RELEVANT_PROJECTS_NOTIFICATION})
                              AND (userstatus != ?)", USER_STATUS_CLOSED)
    translators.each do |translator|
      # find projects that match this translator's profile
      from_language_ids = translator.from_languages.collect(&:id)
      to_language_ids = translator.to_languages.collect(&:id)
      next unless !from_language_ids.empty? && !to_language_ids.empty?

      timewindow = @curtime.to_i - four_hours

      web_messages = translator.open_web_messages("AND (UNIX_TIMESTAMP(web_messages.create_time) < #{timewindow})", nil)
      messages_to_review = translator.web_messages_for_review("AND (UNIX_TIMESTAMP(web_messages.create_time) > #{timewindow})", 20)

      next unless !web_messages.empty? || !messages_to_review.empty?
      begin
        if translator.can_receive_emails? && !translator.skip_instant_translation_email
          ReminderMailer.new_projects_for_translator('New instant translation projects', translator, [], web_messages, messages_to_review, [], [], [], [], false).deliver_now
          cnt += 1
        end
      rescue => e
        puts "error #{e}"
      end
    end
    cnt
  end

  def alert_client_about_instant_messages
    # search for the latest Translation Assistant version for translators
    cnt = 0

    one_day = (24 * 60 * 60).to_i
    web_messages = WebMessage.where("(owner_type IN (?)) AND (translation_status=?) AND (UNIX_TIMESTAMP(web_messages.create_time) < #{@curtime.to_i - one_day})", %w(user client), TRANSLATION_NEEDED)

    # create a dictionary mapping clients to lists of web messages
    clients = {}
    web_messages.each do |web_message|
      client = web_message.owner
      # send only to clients with a full name (registered or paid)
      next unless client && !client.fname.blank? && !client.lname.blank?
      if clients.key?(client)
        clients[client] << web_message
      else
        clients[client] = [web_message]
      end
    end

    clients.each do |client, pending_messages|
      begin
        if client.can_receive_emails?
          ReminderMailer.old_web_messages_alert(client, pending_messages).deliver_now
          cnt += 1
        end
      rescue
      end
    end

    cnt
  end

  def alert_client_about_low_funding
    # This method is disabled until we update it (see icldev-2690).
    #
    # cnt = 0
    # Client.where('(userstatus = ?)  AND (last_login > ?)', USER_STATUS_REGISTERED, Time.zone.now - 14.days).includes(:money_accounts).each do |client|
    #   client.money_accounts.each do |account|
    #     expenses, pending_cms_target_languages, pending_web_messages = account.pending_total_expenses
    #     sig = Digest::MD5.hexdigest(expenses.to_s + pending_cms_target_languages.length.to_s + pending_web_messages.length.to_s)
    #     next unless (expenses > account.balance) && (account.warning_signature != sig)
    #     begin
    #       if client.can_receive_emails?
    #         ReminderMailer.notify_about_low_funding(client, account, expenses, pending_cms_target_languages, pending_web_messages).deliver_now
    #         account.update_attributes(warning_signature: sig)
    #         cnt += 1
    #       end
    #     rescue
    #     end
    #   end
    # end
    # cnt
  end

  def check_for_projects_with_no_progress
    # look for translation languages that have accepted bid on projects, where:
    # 1) Bid was accepted
    # 2) No message or version were uploaded in the last two days
    bids = Bid.includes(:chat).where('(bids.status=?) AND (UNIX_TIMESTAMP(bids.accept_time) < ?) AND (UNIX_TIMESTAMP(bids.expiration_time) > ?)', BID_ACCEPTED, @curtime.to_i - (2 * DAY_IN_SECONDS), @curtime.to_i)

    # don't send this to democlient projects
    democlient = Client.where('email=?', DEMO_CLIENT_EMAIL).first

    root = Root.first
    cnt = 0
    bids.each do |bid|
      chat = bid.chat
      translator = chat.translator
      client = chat.revision.project.client

      if (client != democlient) && no_progress?(chat, root)
        body = build_body(bid, translator, client)
        create_message_in_chat(chat, root, [client, chat.translator], body)
        cnt += 1
      end
    end
    cnt
  end

  def no_progress?(chat, root)
    cms = chat.revision.cms_request
    return false if cms&.base_xliff&.parsed_xliff&.updated_recently?

    ((chat.messages.where("(user_id=#{chat.translator_id}) AND (UNIX_TIMESTAMP(chgtime) >= #{@curtime.to_i - (2 * DAY_IN_SECONDS)})").count == 0) &&
      (chat.revision.versions.where("(by_user_id=#{chat.translator_id}) AND (UNIX_TIMESTAMP(chgtime) >= #{@curtime.to_i - (2 * DAY_IN_SECONDS)})").count == 0) &&
      ((chat.messages.count == 0) || (chat.messages.order('id DESC').first.user_id != root.id)))
  end

  def build_body(bid, translator, client)
    "=== Project status alert ===\n\nNo activity has been made on this project during the last two days.\n\n" \
    "#{translator.full_name}, please remember that the project must be 100% completed by the deadline (#{bid.expiration_time}). Fully completed means that #{client.full_name} must be allowed reasonable time to review the work, comment on it and possibly request corrections. " \
    "You should upload at least once a day and make sure that #{client.full_name} is satisfied with the translation.\n\n" \
    "It's perfectly normal to upload work in progress, much preferable over holding off until it's 100% complete.\n\n" \
    "If either #{translator.full_name} or #{client.full_name} feels that there might be a problem completing this project on time, please contact us by opening a support ticket."
  end

  def rebuild_available_languages
    AvailableLanguage.regenarate
  end

  def elapsed_time
    curtime = Time.zone.now
    dif = curtime.to_i - @basetime.to_i
    @basetime = curtime
    dif
  end

  def remind_about_cms_projects(logger = nil)
    cnt = 0

    timewindow = @curtime.to_i - DAY_IN_SECONDS * 2

    translators = Translator.where('(userstatus != ?)', USER_STATUS_CLOSED)
    translators.each do |translator|
      logger.info "-------- checking translator #{translator.email}" if logger
      last_project_done = translator.cms_target_languages.where("UNIX_TIMESTAMP(updated_at) >= #{Time.zone.now.to_i - timewindow}").first
      logger.info "-------- last_project_done IS NIL #{last_project_done.nil?}" if logger
      next if last_project_done
      open_cms_requests_count = translator.open_website_translation_work.length
      logger.info "-------- open_cms_requests_count #{open_cms_requests_count}" if logger

      next unless open_cms_requests_count > 0
      begin
        if translator.can_receive_emails?
          ReminderMailer.remind_about_cms_projects(translator, open_cms_requests_count).deliver_now
          cnt += 1
        end
      rescue
      end

    end
    cnt
  end

  # Send e-mail to supporters about recently paid language pairs that require
  # "automatic" translator assignment.
  def send_auto_assign_needed_emails
    language_pairs = WebsiteTranslationOffer.needs_auto_assignment
    language_pair_count = language_pairs.size
    return 0 if language_pair_count == 0
    ReminderMailer.auto_assign_needed(language_pairs).deliver_now
    language_pair_count
  end

  def reset_cms_requests_with_no_versions
    cms_requests = CmsRequest.where(['status = ? AND created_at > ?', CMS_REQUEST_WAITING_FOR_PROJECT_CREATION, 1.day.ago]).select { |c| c.revision && c.revision.versions.empty? }

    cms_requests.each do |cms_request|
      cms_request.reset!
      cms_request.retry_tas
      cms_request.note << ' [Automatically Reset]'
      cms_request.save
    end
  end

  def flush_cms_requests
    server = TasComm.new.get_server
    if server
      queue_size = server.call('get_queue_size')
      if queue_size > 100
        raise "TAS queue size too big (#{queue_size}) to send more tasks."
      end
    else
      Rails.logger.info('Not able to check queue size on TAS server')
    end

    cms_requests = CmsRequest.error_requests(@curtime)

    cnt = 0
    cms_requests.each do |cms_request|
      if cms_request.comm_errors.where('comm_errors.status = ?', COMM_ERROR_ACTIVE).length < MAX_COMM_ERRORS
        retry_cms_request(cms_request)
        cnt += 1
      end
    end
    cms_requests.length
  end

  def delete_old_abandoned_uploads
    versions = ZippedFile.where('(owner_id IS NULL) AND (chgtime < ?)', Time.zone.now - 2.days)

    t = {}
    versions.each do |v|
      s = v.class.to_s
      t[s] = 0 unless t.key?(s)
      t[s] += 1
    end
    versions.each(&:destroy)

    t
  end

  def close_old_website_offers
    offers = WebsiteTranslationOffer.where('(status=?) AND (updated_at < ?)', TRANSLATION_OFFER_OPEN, curtime - 14.days)
    websites = {}
    offers.each do |offer|
      website = offer.website
      websites[website] = [] unless websites.key?(website)
      websites[website] << offer
      offer.update_attributes(status: TRANSLATION_OFFER_CLOSED)
    end
    websites.each do |website, closed_offers|
      next unless website && website.client && (website.client.userstatus != USER_STATUS_CLOSED)
      begin
        if website.client.can_receive_emails?
          ReminderMailer.closed_offers_for_website(website, closed_offers).deliver_now
        end
      rescue
      end
    end
    offers.length
  end

  def clean_user_tokens
    should_delete = UserToken.where('created_at < ?', Time.now - UserToken::CLEAN_AFTER)
    cleaned = should_delete.size
    should_delete.delete_all
    cleaned
  end

  # Send e-mail to supporters about auto-assigned translators
  # which have not started after 24 hours the job was accepted
  def send_unstarted_auto_assign_jobs
    cms_requests = CmsRequest.unstarted_auto_assignment_jobs
    return 0 if cms_requests.empty?
    @grouped_cms_requests = cms_requests.group_by(&:id)
    ReminderMailer.unstarted_auto_assign_jobs(@grouped_cms_requests).deliver_now
    @grouped_cms_requests.count
  end

  # Send daily report e-mail to clients about CMS jobs completed for the past 24 hours
  def send_daily_completed_jobs_report
    now = Time.zone.now
    yesterday = now - 24.hours
    cms_requests = CmsRequest.where('status = ? AND completed_at BETWEEN ? AND ?', CMS_REQUEST_DONE, yesterday, now).order(completed_at: :desc)
    grouped_cms_requests = cms_requests.group_by(&:website_id)
    grouped_cms_requests.each do |_website_id, cms_requests_group|
      website = cms_requests_group.first.website
      ReminderMailer.daily_completed_jobs_report(website, cms_requests_group).deliver_now
    end
    grouped_cms_requests.count
  end

  private

  def create_reminder_to_object(object, to_whos, event, new_status)
    reminders = []
    to_whos.each do |to_who|
      reminder = Reminder.new(event: event)
      reminder.normal_user = to_who
      reminder.owner = object
      reminders << reminder
    end
    attempt = 1
    ok = false
    while (attempt < MAX_RETRY_ATTEMPTS) && !ok
      begin
        Reminder.transaction do
          reminders.each(&:save!)
          object.update_attributes!(alert_status: new_status)
          yield if block_given?
        end
        ok = true
      rescue
        attempt += 1
        object.reload
      end
    end
    ok
  end

  def add_notifications_to_translator(translator, objects)
    objects.each do |object|
      sent_notification = SentNotification.new
      sent_notification.user = translator
      sent_notification.owner = object
      sent_notification.save!
    end
  end

  def time_diff(told)
    t = Time.zone.now
    diff = t - told
    [diff, t]
  end
end
