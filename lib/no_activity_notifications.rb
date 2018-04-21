################################ iclweb-42 ###################################
####################### Clients with No activity #############################

class NoActivityNotifications

  def daily_run
    did_not_start_any_project
    wp_did_not_select_a_translator
    software_did_not_accepted_translator_nor_send_string_nor_add_deposit
    bidding_not_accepted_translators
    wp_not_deposited
    software_accepted_translators_no_strings
    software_has_strings_but_no_payment
  end

  def hourly_run
    if Time.now.strftime('%k').to_i.even?
      wp_nothing_sent_to_translation
      software_bidding_did_not_upload_files
      software_bidding_did_not_language
    end
  end

  # 1. Clients registered but did not start any project - 24 hours.
  def did_not_start_any_project
    clients = Client.where(
      'userstatus = ? AND created_at > ?',
      USER_STATUS_REGISTERED, # 1
      24.hours.ago
    ).all
    clients = clients.select { |c| !c.has_projects? }

    deliver(clients)
  end

  # 2. Clients who registered and started a WP site project, but "Nothing was sent to translation in this project." and no languages selected. - 2 hours
  # ToDo Note: Most of the websites created in last 2 hours are anon users.
  def wp_nothing_sent_to_translation
    # TODO: add field on websites
    websites = Website.all(conditions: ['created_at > ? AND anon = 0', 2.hours.ago]).select do |w|
      w.cms_requests.empty? &&
        w.last.website_translation_offers.empty?
    end

    deliver(websites)
  end

  # 3. Clients who registered and started a WP site project, but did not select any translator from those who applied. - 24 hours (?)
  def wp_did_not_select_a_translator
    websites = Website.all(conditions: ['websites.created_at > ? AND anon = 0', 24.hours.ago],
                           joins: [:website_translation_offers]).select do |w|
      w.website_translation_offers.map(&:accepted_website_translation_contracts).flatten.empty?
      # maybe also check that some translator have applied?
    end

    deliver(websites)
  end

  # 4. Clients who started a software/bidding project, but did not upload the file. - 2 hours
  def software_bidding_did_not_upload_files
    # resource_format is set when resource upload is  created
    text_resources = TextResource.all(conditions: ['created_at > ? AND resource_format_id IS NULL', 2.hours.ago]) # .select { |t| t.resource_uploads.empty? }

    deliver(text_resources)
  end

  # 5. Clients who started a software/bidding project, but did not add languages. - 2 hours
  def software_bidding_did_not_language
    projects = TextResource.all(conditions: ['created_at > ?', 2.hours.ago]).select do |t|
      t.resource_languages.empty?
    end

    projects += Project.all(conditions: ['creation_time > ?', 2.hours.ago]).select do |p|
      revision = p.revisions.last

      revision.revision_languages.empty? &&
        revision.cms_request.nil? # exclude website projects
    end

    deliver(projects)
  end

  # 6. Clients who registered and started a software project, but did not accept
  #   translators who applied, and did not send strings to them, and did not add a deposit - 24 hours
  def software_did_not_accepted_translator_nor_send_string_nor_add_deposit
    text_resources = TextResource.all(conditions: ['created_at > ?', 24.hours.ago]).select do |t|
      # ? Maybe chcek also that there are not translating or completed strings?
      t.resource_uploads.any? &&
        t.resource_languages.map { |rl| rl.money_accounts.map &:balance }.flatten.inject(:+) == 0
    end

    deliver(text_resources)
  end

  # 7. Clients who started a bidding project, but did not accept translators who applied, and did not add a deposit.
  def bidding_not_accepted_translators
    projects = Project.all(conditions: ['creation_time > ?', 24.hours.ago]).select do |p|
      revision = p.revisions.last
      bids = revision.all_bids.flatten

      revision.cms_request.nil? && # exclude website projects
        bids.map(&:status).include?(BID_GIVEN) &&
        bids.map(&:account).map(&:balance).inject(:+) == 0
    end

    deliver(projects)
  end

  # 8. Clients who started WP project, but did not add a deposit. - 24 hours
  def wp_not_deposited
    websites = Website.all(conditions: ['created_at > ? AND anon = 0', 24.hours.ago]).select do |_w|
      website.cms_requests.map(&:revision).map(&:all_bids).flatten.map(&:account).map(&:balance).inject(:+) == 0
    end

    deliver(websites)
  end

  # 9. Clients who started a software project, accepted translators but didn’t send strings.
  def software_accepted_translators_no_strings
    text_resources = TextResource.all(conditions: ['created_at > ?', 24.hours.ago]).select do |t|
      t.resource_languages.map(:selected_chat).any? &&
        t.resource_uploads.empty?
    end

    deliver(text_resources)
  end

  # 10. Clients who started a software project, accepted translators, sent strings but didn’t pay.
  def software_has_strings_but_no_payment
    text_resources = TextResource.all(conditions: ['created_at > ?', 24.hours.ago]).select do |t|
      t.resource_languages.map(:selected_chat).any? &&
        t.resource_uploads.any? &&
        t.resource_strings.map(&:string_translations).map(:status).uniq == [STRING_TRANSLATION_MISSING]
    end

    deliver(text_resources)
  end

  private

  # Deliver using ReminderMailer
  # First item of args must be an array of clients
  def deliver(objects)
    caller_method_name = caller[0][/`([^']*)'/, 1]

    objects.each do |item|
      client = item.is_a?(Client) ? item : item.client
      raise "#{client} is not a client" unless client.is_a? Client

      if client.can_receive_emails?
        ReminderMailer.send(caller_method_name, item).deliver_now
      end
    end
  end
end
