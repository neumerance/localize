class ActiveTrailAction < ApplicationRecord
  belongs_to :project, polymorphic: true
  # Required for the "translator assignment required" flow, to keep track of
  # which language pairs requiring assignment have already triggered e-mails, so
  # we don't send multiple e-mails to a client about the same language pair.
  has_many :website_translation_offers, dependent: :nullify

  validates :project, :action, :subject, presence: true
  validates :cta_button_link, presence: true, unless: 'subject == "no_jobs_sent"'

  # The "no jobs sent" flow should only be triggered once per website.
  # TODO: consider creating a custom validator class
  validates :project,
            uniqueness: {
              scope: [:action, :subject],
              message: 'The "no jobs sent" flow should only be triggered once per project.'
            },
            if: 'new_record? && subject == "no_jobs_sent"'

  # After triggering the "payment required" flow once, it should only be
  # triggered again (send another e-mail to the same client, regarding the same
  # project) after a payment is received. In other words, it is only OK to send
  # a second e-mail in the following scenario: we send the first e-mail,
  # the client pays, client sends more translation jobs and doesn't pay for them.
  # TODO: consider creating a custom validator class
  validates :project,
            uniqueness: {
              scope: [:action, :subject],
              message: 'The "payment required" flow cannot be triggered for a ' \
                       'second time before a payment is received.'
            },
            if: 'new_record? && subject == "payment_required" && !received_payment_after_last_triggered?'

  # The "translator assignment required" flow should only be triggered once per
  # language pair.
  # TODO: consider creating a custom validator class
  validates :project,
            uniqueness: {
              scope: [:action, :subject],
              message: 'The "translator assignment required" flow should ' \
                       'only be triggered once per language pair.'
            },
            if: 'new_record? && subject == "translator_assignment_required" && triggered_before_for_language_pairs?'

  enum action: {
    # Send e-mail to client
    send_email: 0
  }

  enum subject: {
    no_jobs_sent: 0,
    translator_assignment_required: 1,
    payment_required: 2
  }

  # ActiveTrails group IDs corresponding to the above subjects
  AT_GROUPS = {
    no_jobs_sent: 50477,
    translator_assignment_required: 50475,
    payment_required: 49913
  }.with_indifferent_access.freeze

  # Websites whose clients did not send any translation jobs from WPML.
  def self.websites_with_no_jobs_sent
    # Exclude websites created too long ago to save DB resources.
    expiration_date = 3.days.ago.to_s(:db)
    action_code = ActiveTrailAction.actions['send_email']
    subject_code = ActiveTrailAction.subjects['no_jobs_sent']

    query = <<-SQL
        SELECT DISTINCT websites.id
        FROM websites
        WHERE
          websites.created_at BETWEEN "#{expiration_date}" AND "#{2.days.ago.to_s(:db)}"
          -- Does not have any translation jobs
          AND NOT EXISTS(
              SELECT 1
              FROM cms_requests
              WHERE cms_requests.website_id = websites.id
          )
          -- The "no jobs sent" flow should only be triggered once per website.
          AND NOT EXISTS(
              SELECT 1
              FROM active_trail_actions AS ata
              WHERE ata.project_id = websites.id
                AND ata.project_type = 'Website'
                AND ata.action = #{action_code}
                AND ata.subject = #{subject_code}
          )
    SQL

    Website.find_by_sql(query)
  end

  # Notify all clients that created an ICL account, linked to WPML (which means
  # a website translation project was created) but did not send any jobs for
  # translation.
  def self.notify_websites_no_jobs_sent
    raise 'Should only be run in production, will send real e-mails!' unless Rails.env.production?
    result = websites_with_no_jobs_sent.map { |website| trigger_no_jobs_sent_flow(website.id) }
    # Count of projects whose clients were notified
    result.count(true)
  end

  # Client created an ICL account but did not send WPML jobs for translation.
  def self.trigger_no_jobs_sent_flow(website_id)
    attributes = {
      project_type: 'Website',
      project_id: website_id,
      action: :send_email,
      subject: :no_jobs_sent
    }
    record = self.create(attributes)
    unless record.valid?
      Logging.log(self, 'Tried to trigger inappropriate ActiveTrail ' \
                        "automation. #{record.errors.messages}: #{attributes}")
      return false
    end
    record.send(:add_website_to_group)
  end

  # Websites that have translation jobs in manual translator assignment language
  # pairs for which the client did not yet invite any translators.
  def self.websites_translator_invitation_required
    # Exclude jobs created too long ago to save DB resources.
    job_expiration_date = 1.day.ago.to_s(:db)

    query = <<-SQL
      SELECT
        websites.id as website_id,
        -- Comma separated list of IDs of WTOs requiring translator invitation
        GROUP_CONCAT(DISTINCT wto.id) as wto_ids
      FROM websites
        INNER JOIN cms_requests
          ON cms_requests.website_id = websites.id
             AND cms_requests.status = 4
             AND cms_requests.created_at BETWEEN  "#{job_expiration_date}" AND "#{1.hour.ago.to_s(:db)}"
        INNER JOIN cms_target_languages AS ctl
          ON ctl.cms_request_id = cms_requests.id
             AND ctl.status = 0
        INNER JOIN website_translation_offers as wto
          ON wto.from_language_id = cms_requests.language_id
             AND wto.to_language_id = ctl.language_id
             AND wto.website_id = websites.id
             AND wto.automatic_translator_assignment = 0
        WHERE
          /* The "translator assignment required" automation was never
          triggered for this language pair */
          wto.active_trail_action_id IS NULL
          AND NOT EXISTS(
            SELECT 1
            FROM website_translation_contracts as wtc
            WHERE wtc.website_translation_offer_id = wto.id
                  AND wtc.status != 3
          )
        GROUP BY websites.id
    SQL

    # Returns an array of hashes with the following format:
    # [{"website_id"=>21677, "wto_ids"=>"23370"},
    #  {"website_id"=>73456, "wto_ids"=>"53040,53041"}]
    Website.connection.select_all(query).to_a
  end

  # Notify the owners of all websites that have sent translation jobs for manual
  # translator assignment language pairs but did not invite any translators.
  def self.notify_websites_translator_invitation_required
    raise 'Should only be run in production, will send real e-mails!' unless Rails.env.production?
    result = websites_translator_invitation_required.map do |website_and_wto_ids|
      trigger_translator_invitation_required_flow(website_and_wto_ids)
    end
    # Count of projects whose clients were notified
    result.count(true)
  end

  # Client sent translation jobs for manual translator assignment language
  # pairs but did not invite any translators.
  def self.trigger_translator_invitation_required_flow(website_and_wto_ids)
    wto_ids = website_and_wto_ids['wto_ids'].split(',').map(&:to_i)
    attributes = {
      project_type: 'Website',
      project_id: website_and_wto_ids['website_id'],
      action: :send_email,
      subject: :translator_assignment_required,
      website_translation_offers: WebsiteTranslationOffer.where(id: wto_ids),
      cta_button_link: "https://www.icanlocalize.com/wpml/websites/#{website_and_wto_ids['website_id']}/translation_jobs"
    }
    record = self.create(attributes)
    unless record.valid?
      Logging.log(self, 'Tried to trigger inappropriate ActiveTrail ' \
                        "automation. #{record.errors.messages}: #{attributes}")
      return false
    end
    record.send(:add_website_to_group)
  end

  # Websites that have translation jobs created more than one hour ago and
  # still not paid for.
  def self.websites_payment_required
    # Exclude jobs created too long ago to save DB resources.
    job_expiration_date = 1.day.ago.to_s(:db)
    action_code = ActiveTrailAction.actions['send_email']
    subject_code = ActiveTrailAction.subjects['payment_required']

    query = <<-SQL
      SELECT DISTINCT websites.id
      FROM websites
        INNER JOIN cms_requests
          ON cms_requests.website_id = websites.id
             AND cms_requests.status = 4
             AND cms_requests.created_at BETWEEN "#{job_expiration_date}" AND "#{1.hour.ago.to_s(:db)}"
        INNER JOIN cms_target_languages AS ctl
          ON ctl.cms_request_id = cms_requests.id
             AND ctl.status = 0
        INNER JOIN website_translation_offers as wto
          ON wto.from_language_id = cms_requests.language_id
             AND wto.to_language_id = ctl.language_id
             AND wto.website_id = websites.id
        LEFT OUTER JOIN website_translation_contracts AS wtc
          ON wto.id = wtc.website_translation_offer_id
      WHERE
        /* The website must have at least one "payable" language pair. Language
        pairs set to automatic translator assignment are payable from the start.
        Language pairs set to manual translator assignment are only payable after
        a translator is assigned by the client. */
        (wto.automatic_translator_assignment = 1 OR wtc.status = 2)
        /* The cms_requests of the website may be all unpaid, or a mix of paid and
        unpaid. The point is, it must contain at least one unpaid cms_request */
        AND NOT EXISTS(
          SELECT 1
          FROM pending_money_transactions AS pmt
          WHERE pmt.owner_id = cms_requests.id
                AND pmt.owner_type = 'CmsRequest'
                AND pmt.deleted_at IS NULL
          )
          /* After triggering the "payment required" flow once, it should only be
          triggered again (send another e-mail to the same client, regarding the
          same project) after a payment is received. In other words, it is only OK
          to send a second e-mail in the following scenario: we send the first
          e-mail, the client pays, client sends more translation jobs and doesn't
          pay for them. */
        AND NOT(
          /* Last time this automation was triggered for this website, for any
          translation job */
          COALESCE(
            (SELECT MAX(ata.performed_at)
             FROM active_trail_actions AS ata
             WHERE
                ata.project_id = websites.id
                AND ata.project_type = 'Website'
                AND ata.action = #{action_code}
                AND ata.subject = #{subject_code}),
             0)
          >
          /* Last time this website received a payment from the client (for
          any translation job */
          COALESCE(
            (SELECT MAX(pmt.created_at)
             FROM pending_money_transactions AS pmt
             INNER JOIN cms_requests AS any_cms_request
             WHERE
                any_cms_request.website_id = websites.id
                AND pmt.owner_id = any_cms_request.id
                AND pmt.owner_type = 'CmsRequest'
                AND pmt.deleted_at IS NULL),
             0)
        )
    SQL

    website_ids = Website.find_by_sql(query)
    # Must return an ActiveRecord::Relation object
    Website.where(id: website_ids)
  end

  # Notify the owners of all websites that have translation jobs created more
  # one hour ago and still not paid for.
  def self.notify_websites_payment_required
    raise 'Should only be run in production, will send real e-mails!' unless Rails.env.production?
    result = websites_payment_required.map { |w| email_payment_required(w) }
    # Count of projects whose clients were notified
    result.count(true)
  end

  # Client sent jobs, assigned a translator (or chosen automatic translator
  # assignment) but didn't pay.
  def self.email_payment_required(website)
    # Give it another hour before triggering the automation if the client has
    # received has paid for jobs in the past (so he's more likely to pay again).
    return if website.any_payment_received? && website.last_job_sent_at > 2.hours.ago
    attributes = {
      project: website,
      action: :send_email,
      subject: :payment_required,
      cta_button_link: "https://www.icanlocalize.com/wpml/websites/#{website.id}/translation_jobs"
    }
    record = self.create(attributes)
    unless record.valid?
      Logging.log(self, 'Tried to trigger inappropriate ActiveTrail ' \
                        "automation. #{record.errors.messages}: #{attributes}")
      return false
    end
    record.send(:add_website_to_group)
  end

  private

  # If the contact was added to this ActiveTrail group before, fetch previous
  # records with the same action and subject (regardless of project).
  def previous_records_for_same_client
    self.class.where(
      action: action,
      subject: subject
    )
  end

  # If the contact was added to this ActiveTrail group before, fetch previous
  # records with the same project, action and subject.
  def previous_records_for_same_project
    previous_records_for_same_client.where(
      project: project
    )
  end

  # If contact (e.g., client) was added to an ActiveTrail group before, we have
  # to fetch it's 'contact ID' if we want to update or remove him from the group.
  def contact_id_from_previous_record
    previous_records_for_same_client.pluck(:active_trail_contact_id).compact.last
  end

  # Was this automation triggered before (was this client was added to this
  # ActiveTrail group before) for the same project (website)?
  def triggered_before_for_same_project?
    # If there is a contact ID, it means we got a successful response from AT.
    previous_records_for_same_project.pluck(:active_trail_contact_id).compact.any?
  end

  # Last time the client was added to this ActiveTrail group regarding the same
  # project(website).
  def last_triggered_at
    previous_records_for_same_project.maximum(:performed_at)
  end

  # Did the project receive payment after the last time the client was added
  # to this ActiveTrail group (after the last time this automation was triggered?)
  def received_payment_after_last_triggered?
    triggered_before_for_same_project? &&
      project.last_payment_received_at &&
      project.last_payment_received_at > last_triggered_at
  end

  # Was this automation triggered before (client was added to ActiveTrail group)
  # for this website and all of these the language pairs?
  def triggered_before_for_language_pairs?
    previous_records_for_same_project.any? do |at_action|
      (self.website_translation_offers - at_action.website_translation_offers).empty?
    end
  end

  # Add a website translation project to an ActiveTrail contact group to start
  # and automation flow (send e-mails to the client that owns then website).
  def add_website_to_group
    Logging.log(self, "Triggering #{self.subject} automation for " \
                      "#{project.class} #{project.id} (#{project.client.email})")

    # Most flows can be triggered multiple times. For the automation to be
    # re-triggered for the same contact (client), we have to remove and readd
    # the contact to the ActiveTrail group.
    ApiAdapters::ActiveTrail.new.remove_user_from_group(
      AT_GROUPS[self.subject],
      contact_id_from_previous_record
    )

    response = ApiAdapters::ActiveTrail.new.add_user_to_group(
      project,
      AT_GROUPS[self.subject],
      cta_button_link: cta_button_link,
      language_pair_names: website_translation_offers&.map(&:language_pair)&.to_sentence
    )

    if response
      self.update!(active_trail_contact_id: response['id'])
    else
      self.destroy
      false
    end
  rescue StandardError => e
    Logging.log(self, e)
    self.destroy
  end

  def timestamp_attributes_for_create
    ['performed_at']
  end

  # No updated_at column required
  def timestamp_attributes_for_update
    []
  end
end
