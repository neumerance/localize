require 'remembers.rb'
require 'securerandom'
require 'digest/md5'
class Translator < NormalUser
  include Remembers

  has_many :chats
  has_many :translator_languages
  has_many :all_languages, through: :translator_languages, source: :language, class_name: 'Language'

  has_many :from_languages,
           -> { where("(translator_languages.type = 'TranslatorLanguageFrom') AND (translator_languages.status = ?)", TRANSLATOR_LANGUAGE_APPROVED) },
           through: :translator_languages,
           source: :language,
           class_name: 'Language'
  has_many :to_languages,
           -> { where("(translator_languages.type = 'TranslatorLanguageTo') AND (translator_languages.status = ?)", TRANSLATOR_LANGUAGE_APPROVED) },
           through: :translator_languages,
           source: :language,
           class_name: 'Language'

  has_many :all_from_languages,
           -> { where("(translator_languages.type = 'TranslatorLanguageFrom')") },
           through: :translator_languages,
           source: :language,
           class_name: 'Language'
  has_many :all_to_languages,
           -> { where("(translator_languages.type = 'TranslatorLanguageTo')") },
           through: :translator_languages,
           source: :language,
           class_name: 'Language'

  has_many :language_pair_autoassignments, class_name: 'TranslatorLanguagesAutoAssignment'

  has_many :categories, through: :translator_categories
  has_many :translator_categories
  has_many :translator_language_froms
  has_many :translator_language_tos
  has_many :web_messages
  has_many :website_translation_contracts
  has_many :cms_target_languages
  has_many :cms_requests, through: :cms_target_languages

  has_many :active_web_messages, -> { where('translation_status=?', TRANSLATION_IN_PROGRESS) }, class_name: 'WebMessage', foreign_key: :translator_id

  has_many :accepted_offers,
           -> { where('(website_translation_offers.status != ?) AND (website_translation_contracts.status=?)', TRANSLATION_OFFER_SUSPENDED, TRANSLATION_CONTRACT_ACCEPTED) },
           through: :website_translation_contracts,
           source: :website_translation_offer,
           class_name: 'WebsiteTranslationOffer'

  has_many :private_translators, dependent: :destroy
  has_many :patrons,
           -> { where('private_translators.status=?', PRIVATE_TRANSLATOR_ACCEPTED) },
           through: :private_translators,
           source: :client,
           class_name: 'Client'

  has_many :private_clients, through: :private_translators, source: :client, class_name: 'Client'
  has_many :resource_chats
  has_many :managed_works, dependent: :destroy
  has_many :tus
  has_many :translators_refused_projects
  has_many :tmt_configs

  after_save :rescan_languages

  STATUS_CODES = { red: 0, yellow: 1, green: 2 }.freeze

  # Revision.find_by_sql('SELECT distinct revisions.* FROM revisions INNER JOIN chats ON (revisions.id = chats.revision_id) INNER JOIN bids ON (chats.id = bids.chat_id) WHERE ((chats.translator_id = 3) AND (bids.status = 2)) ORDER BY bids.id DESC LIMIT 4')
  def revisions(condition = nil, extra_sql = '')
    cond_str = if condition
                 " AND #{condition}"
               else
                 ''
               end
    Revision.find_by_sql("SELECT DISTINCT revisions.* FROM revisions INNER JOIN chats ON (revisions.id = chats.revision_id) INNER JOIN bids ON (chats.id = bids.chat_id) WHERE ((chats.translator_id = #{id})#{cond_str}) #{extra_sql}")
  end

  def selected_resource_chats
    resource_chats.where(status: RESOURCE_CHAT_ACCEPTED)
  end

  def selected_chats
    chats.find_all(&:has_accepted_bid)
  end

  def projects
    # TODO: Optimize
    revisions.map(&:project)
  end

  def can_view?(project)
    if project.is_a? Project
      # projects.include?(project)
      true
    elsif project.is_a? Website
      false
    elsif project.is_a? WebMessage
      web_messages.include?(project)
    elsif project.is_a? TextResource
      text_resources.include?(project) || open_text_resource_projects.map(&:text_resource).include?(project)
    elsif project.is_a? WebsiteTranslationContract
      wto = project.website_translation_offer
      ((self == project.translator) && (private_translator? || has_language_pair(wto.to_language, wto.from_language))) ||
        (wto.managed_work && wto.managed_work.active? && [self, nil].include?(wto.managed_work.translator))
    else
      raise 'Unknown project class'
    end
  end

  def can_modify?(project)
    if project.is_a? Revision
      return true if is_reviewer_of?(project)
      project = project.project
    end
    if project.is_a? Project
      projects.include?(project)
    elsif project.is_a? Website
      websites.include?(project)
    elsif project.is_a? WebMessage
      web_messages.include?(project) || project.try(:managed_work).try(:translator) == self
    elsif project.is_a? WebsiteTranslationContract
      managed_work = project.website_translation_offer.managed_work
      managed_work ||= ManagedWork.new
      [project.translator, managed_work.translator].include? self
    elsif project.is_a? TextResource
      text_resources.include?(project)
    elsif project.is_a? CmsRequest
      cms_requests.include?(project)
    elsif project.is_a? XliffTransUnitMrk
      project.cms_request.translator == self
    else
      raise "Unknown project class #{project.class}"
    end
  end

  def language_pairs
    Hash[from_languages.map { |l| [l, to_languages] }]
  end

  def language_pair_autoassign_settings(from_language, to_language)
    language_pair_autoassignments.find_or_initialize_by(
      from_language: from_language,
      to_language: to_language
    )
  end

  # get translators that are autoassignable to a given language pair
  def self.autoassign_for(from_language, to_language)
    autoassignable_for("#{from_language.id}_#{to_language.id}")
  end

  def self.autoassignable_for(language_pair_id)
    query = "SELECT u.id, u.fname, u.lname, u.nickname, u.last_login, COUNT(c.id) AS jobs_in_progress, u.level
                FROM `users` AS u
                  INNER JOIN translator_languages_auto_assignments AS a
                    ON u.id = a.translator_id
                  LEFT OUTER JOIN cms_target_languages AS c
                    ON u.id = c.translator_id AND c.status = 1
                WHERE u.last_login  > (SELECT DATE_SUB(NOW(), INTERVAL 60 day))
                  AND a.language_pair_id = '#{language_pair_id}'
                GROUP BY u.id HAVING jobs_in_progress < #{MAX_ALLOWED_CMS_PROJECTS}
                ORDER BY u.last_login DESC
                LIMIT 10"
    data = ActiveRecord::Base.connection.execute(query).to_a.map do |row|
      {
        name: row[3].present? ? row[3] : "#{row[1]} #{row[2]}",
        last_login: row[4],
        jobs_in_progress: row[5],
        id: row[0],
        level: row[6]
      }
    end
    data
  end

  def has_language_pair(to_language, from_language)
    has_to_language(to_language) && has_from_language(from_language)
  end

  def has_to_language(to_language)
    to_languages.where(['translator_languages.language_id=?', to_language.id]).first
  end

  def has_from_language(from_language)
    from_languages.where(['translator_languages.language_id=?', from_language.id]).first
  end

  def text_resources
    TextResource.distinct.joins(:resource_chats).where('resource_chats.status = ?', RESOURCE_CHAT_ACCEPTED)
  end

  def assigned_text_resources
    text_resources = TextResource.distinct.joins(:resource_chats).where('resource_chats.status = ? AND resource_chats.translator_id = ?', RESOURCE_CHAT_ACCEPTED, self.id).to_a
    review_works = managed_works.includes(:resource_language).where(active: MANAGED_WORK_ACTIVE, owner_type: 'ResourceLanguage')
    if review_works.any?
      resource_languages = ResourceLanguage.includes(:text_resource).where(id: review_works.collect(&:owner_id).uniq)
      text_resources << resource_languages.collect(&:text_resource).uniq
    end
    text_resources.flatten.uniq
  end

  def work_revisions(extra_sql = '', only_ta_projects = false, params = {})

    project_filter = only_ta_projects ? "(r.kind = #{TA_PROJECT}) AND" : ''
    page = params[:page] ||= 1
    per = params[:per_page] ||= 20
    cached('work_revisions' + extra_sql) do
      Kaminari.paginate_array(
        Revision.find_by_sql("SELECT DISTINCT r.*
        FROM revisions r, chats c
        WHERE #{project_filter} (r.id = c.revision_id) AND (c.translator_id = #{id})
        AND EXISTS (
          SELECT b.id
          FROM bids b
          WHERE b.chat_id = c.id
          AND b.status IN (#{[BID_ACCEPTED, BID_DECLARED_DONE].join(',')}) ) ORDER BY r.id DESC #{extra_sql};")
      ).page(page).per(per)
    end
  end

  def pending_cms_chats
    cached('pending_cms_chats') do
      Chat.find_by_sql("SELECT DISTINCT c.*
      FROM revisions r, chats c, cms_requests cms
      WHERE (r.kind = #{TA_PROJECT}) AND (r.cms_request_id IS NOT NULL) AND (r.id = c.revision_id) AND (c.translator_id = #{id}) AND (r.cms_request_id = cms.id)
      AND EXISTS (
        SELECT b.id
        FROM bids b
        WHERE b.chat_id = c.id
        AND b.status IN (#{[BID_ACCEPTED, BID_WAITING_FOR_PAYMENT].join(',')}) ) ORDER BY c.revision_id DESC;")
    end
  end

  def excluded_revisions_sql(revisions)
    if revisions.empty?
      ''
    else
      "(r.id NOT IN (#{revisions.collect(&:id).join(',')})) AND "
    end
  end

  def bid_revisions(extra_sql = '', only_ta_projects = false, params = {})

    project_filter = only_ta_projects ? "(r.kind = #{TA_PROJECT}) AND" : ''
    page = params[:page] ||= 1
    per = params[:per_page] ||= 20
    cached('bid_revisions' + extra_sql) do
      Kaminari.paginate_array(
        Revision.find_by_sql("SELECT DISTINCT r.*

        FROM revisions r, chats c
        WHERE #{project_filter} #{excluded_revisions_sql(completed_revisions)} (r.id = c.revision_id) AND (c.translator_id = #{id})
        AND (EXISTS (
            SELECT b.id FROM bids b
            WHERE b.chat_id = c.id AND b.status IN (#{BID_GIVEN})
            AND NOT EXISTS (SELECT winning_bid.id FROM bids winning_bid
              WHERE (winning_bid.revision_language_id = b.revision_language_id) AND (winning_bid.status IN (#{BID_ACCEPTED_STATUSES.join(',')}))))
          OR EXISTS (
            SELECT m.id FROM messages m
            WHERE m.owner_id=c.id AND m.owner_type='Chat') AND EXISTS (
              SELECT rl.id from revision_languages rl WHERE (rl.revision_id = r.id) AND NOT EXISTS (
                SELECT assigned_b.id FROM bids assigned_b
                WHERE (assigned_b.revision_language_id = rl.id) AND (assigned_b.won = 1)
              ))
            )
        AND NOT exists (
          SELECT other_b.id FROM bids other_b
          WHERE other_b.chat_id = c.id
          AND other_b.status IN (#{[BID_ACCEPTED, BID_DECLARED_DONE].join(',')}))
        ORDER BY r.id DESC #{extra_sql};")
      ).page(page).per(per)
      # AND (UNIX_TIMESTAMP(r.bidding_close_time) > #{Time.now().to_i}) - removed this so that old projects still show
    end
  end

  def all_bid_revisions(extra_sql = '', only_ta_projects = false)

    project_filter = only_ta_projects ? "(r.kind = #{TA_PROJECT}) AND" : ''

    cached('all_bid_revisions' + extra_sql) do
      Revision.find_by_sql("SELECT DISTINCT r.*

      FROM revisions r, chats c
      WHERE #{project_filter} (r.id = c.revision_id) AND (c.translator_id = #{id})
      AND EXISTS ((
        SELECT b.id FROM bids b
        WHERE b.chat_id = c.id AND b.status IN (#{BID_GIVEN}) )
        OR EXISTS (
        SELECT m.id FROM messages m
        WHERE m.owner_id=c.id AND m.owner_type='Chat'))
      AND NOT exists (
        SELECT other_b.id FROM bids other_b
        WHERE other_b.chat_id = c.id
        AND other_b.status IN (#{[BID_ACCEPTED, BID_DECLARED_DONE].join(',')}))
      AND (UNIX_TIMESTAMP(r.bidding_close_time) > #{Time.now.to_i})
      ORDER BY r.id DESC #{extra_sql};")
    end
  end

  def all_chats_from_bids_that_won
    Chat.joins(:bids).where('translator_id = ? AND bids.won = 1', id)
  end

  def completed_revisions(params = {})
    extra_sql = params[:extra_sql] ||= ''
    only_ta_projects = params[:only_ta_projects] ||= false
    page = params[:page] ||= 1
    per = params[:per_page] ||= 20
    # different cache key based on arguments010
    key = method(__method__).parameters.map { |arg| arg[1] }.map { |arg| "#{arg} = #{eval arg.to_s}" }.join(', ')
    Rails.cache.fetch("#{self.cache_key}/completed_projects-#{key}", expires_in: CACHE_DURATION) do
      project_filter = only_ta_projects ? "(r.kind = #{TA_PROJECT}) AND" : ''
      Kaminari.paginate_array(
        Revision.find_by_sql("SELECT DISTINCT r.*
        FROM revisions r, chats c
        WHERE #{project_filter} (r.id = c.revision_id) AND (c.translator_id = #{id})
        AND EXISTS (
          SELECT b.id
          FROM bids b
          WHERE b.chat_id = c.id
          AND b.status IN (#{BID_COMPLETE_STATUS.join(',')}) )
        AND NOT EXISTS (
          SELECT b.id
          FROM bids b WHERE b.chat_id = c.id
          AND b.status IN (#{BID_ACCEPTED}) )
        AND NOT EXISTS (
          SELECT b.id
          FROM bids b
          WHERE b.chat_id = c.id
          AND b.status IN (#{BID_GIVEN}) AND (UNIX_TIMESTAMP(r.bidding_close_time) > #{Time.now.to_i}) )
        ORDER BY r.id DESC #{extra_sql};")
      ).page(page).per(per)
    end
  end

  def open_revisions(extra_sql = '', only_ta_projects = false)

    project_filter = only_ta_projects ? "(r.kind = #{TA_PROJECT}) AND" : ''

    cached('open_revisions' + extra_sql) do
      Revision.find_by_sql("SELECT DISTINCT r.*
      FROM revisions r
      WHERE #{project_filter}
      NOT EXISTS (
        SELECT c.id from chats c
        WHERE (r.id = c.revision_id)
        AND (c.translator_id = #{id}) AND (
          EXISTS (SELECT m.id from messages m WHERE (m.owner_id=c.id AND m.owner_type='Chat')) OR
          EXISTS (SELECT b1.id from bids b1 WHERE (b1.chat_id=c.id))
        )
      )
      AND EXISTS (
        SELECT rl.id from revision_languages rl WHERE (rl.revision_id = r.id) AND NOT EXISTS (
          SELECT b.id FROM bids b
          WHERE (b.revision_language_id = rl.id) AND (b.won = 1)
        )
      )
      AND (r.released = 1) AND (UNIX_TIMESTAMP(r.bidding_close_time) > #{Time.now.to_i}) ORDER BY r.id DESC #{extra_sql};")

    end
  end

  def private_translator?
    userstatus == USER_STATUS_PRIVATE_TRANSLATOR
  end

  def open_revisions_filtered(include_languages, include_categories, other_conditions = '', extra_sql = '')
    # different cache key based on arguments
    key = method(__method__).parameters.map { |arg| arg[1] }.map { |arg| "#{arg} = #{eval arg.to_s}" }.join(', ')
    Rails.cache.fetch("#{self.cache_key}/open_revisions_filtered-#{key}", expires_in: CACHE_DURATION) do
      if (userstatus != USER_STATUS_PRIVATE_TRANSLATOR) && include_languages
        to_lang_sql = "AND EXISTS (SELECT translator_lang.id FROM translator_languages translator_lang
                WHERE (translator_lang.translator_id = #{id}) AND (translator_lang.language_id = rl.language_id) AND (translator_lang.type = 'TranslatorLanguageTo') AND (translator_lang.status=#{TRANSLATOR_LANGUAGE_APPROVED}))"
        orig_lang_sql = "AND EXISTS (SELECT translator_from_lang.id FROM translator_languages translator_from_lang
                WHERE (translator_from_lang.translator_id = #{id}) AND (translator_from_lang.language_id = r.language_id) AND (translator_from_lang.type = 'TranslatorLanguageFrom') AND (translator_from_lang.status=#{TRANSLATOR_LANGUAGE_APPROVED}))"
      else
        to_lang_sql = ''
        orig_lang_sql = ''
      end

      categories_sql = if (userstatus != USER_STATUS_PRIVATE_TRANSLATOR) && include_categories
                         # see that there's no required category that the translator doesn't do
                         "AND NOT EXISTS (SELECT * FROM revision_categories WHERE (
                           (revision_categories.revision_id = r.id) AND NOT EXISTS (
                             SELECT * FROM translator_categories WHERE (translator_categories.translator_id = #{id}) AND (translator_categories.category_id=revision_categories.category_id))
                           ))"
                       else
                         ''
                       end

      logger.info "---- looking for bidding project for translator #{email}"
      if userstatus != USER_STATUS_PRIVATE_TRANSLATOR
        private_translator_sql = 'AND (r.is_test != 1)'
      else
        patron_ids = patrons.collect(&:id)
        if patron_ids.empty?
          logger.info '---- sorry, no patrons'
          return []
        end
        private_translator_sql = "AND EXISTS (SELECT p.id FROM projects p WHERE (r.project_id=p.id AND p.client_id IN (#{patron_ids.join(',')})))"
      end

      res = Revision.find_by_sql("SELECT DISTINCT r.*
        FROM revisions r
        WHERE
        NOT EXISTS (
          SELECT c.id from chats c
          WHERE (r.id = c.revision_id)
          AND (c.translator_id = #{id}) AND (
            EXISTS (SELECT m.id FROM messages m WHERE (m.owner_id=c.id AND m.owner_type='Chat')) OR
            EXISTS (SELECT b1.id FROM bids b1 WHERE (b1.chat_id=c.id))
          )
        )
        AND EXISTS (
          SELECT rl.id from revision_languages rl WHERE (rl.revision_id = r.id) AND NOT EXISTS (
            SELECT b.id FROM bids b
            WHERE (b.revision_language_id = rl.id) AND (b.won = 1)
          ) #{to_lang_sql}
        )
        #{orig_lang_sql} #{categories_sql} #{private_translator_sql} AND (r.released = 1) AND (UNIX_TIMESTAMP(r.bidding_close_time) > #{Time.now.to_i} #{other_conditions}) ORDER BY r.id DESC #{extra_sql};")

      res
    end
  end

  def can_do_training?
    !translator_language_froms.empty? && !translator_language_tos.empty?
  end

  def release_cms_jobs(website, language)
    target_languages = website.cms_target_languages.where(language_id: language.id, translator_id: id)
    target_languages.each { |tl| tl.translator = nil; tl.save! }
  end

  def todos(count_only = nil)
    todos = [] # list of things that need to be done
    active_items = 0

    if userstatus != USER_STATUS_PRIVATE_TRANSLATOR
      from_lang_status = tl_todo_status(translator_language_froms)
      todos << [from_lang_status, _('Select languages to translate from'), _('When searching for new projects, the system will return projects that match the languages you can translate from.'), { controller: :users, action: :translator_languages, id: id, anchor: 'fromlanguages' }, true]
      active_items += 1 if count_only ? (from_lang_status == count_only) : (from_lang_status != TODO_STATUS_DONE)

      to_lang_status = tl_todo_status(translator_language_tos)
      todos << [to_lang_status, _('Select languages to translate to'), _('When searching for new projects, the system will return projects that match the languages you can translate to.'), { controller: :users, action: :translator_languages, id: id, anchor: 'tolanguages' }, true]
      active_items += 1 if count_only ? (to_lang_status == count_only) : (to_lang_status != TODO_STATUS_DONE)

      u_active_items, u_todos = super(count_only)
      active_items += u_active_items
      todos += u_todos

      bionote_ok = (bionote && !bionote.body.blank?)

      todos << [bionote_ok ? TODO_STATUS_DONE : TODO_STATUS_MISSING, _('Enter a short bio-note'), _('A bio-note is a short text that tells about you. Without it, we cannot show your profile when clients look for translators.'), { controller: :users, action: :show, id: id }, true]
      active_items += 1 unless bionote_ok

      if bionote_ok
        bio_translations = {}
        bionote.db_content_translations.each { |bio_translation| bio_translations[bio_translation.language] = bio_translation }

        all_languages.where(name: 'English').find_each do |language|
          bio_translation_ok = true # bio_translations.key?(language)
          todos << [bio_translation_ok ? TODO_STATUS_DONE : TODO_STATUS_MISSING, _('Translate your bio-note to %s') % language.name, _('%s speaking clients will first see translators who have %s bio-notes') % [language.name, language.name], { controller: :users, action: :show, id: id }, true]
          active_items += 1 unless bio_translation_ok
        end
      end

      todos << [!country.blank? ? TODO_STATUS_DONE : TODO_STATUS_MISSING, _('Select your nationality'), _('Your nationality helps clients understand your language specialization.'), { controller: :users, action: :show, id: id, anchor: 'personal_details' }, true]
      active_items += 1 if country.blank?

      todos << [resume && !resume.body.blank? ? TODO_STATUS_DONE : TODO_STATUS_MISSING, _('Create a resume'), _('A resume shows other users what your background is.'), { controller: :users, action: :show, id: id, anchor: 'resume' }, true]
      active_items += 1 unless resume && !resume.body.blank?

      rate_and_capacity_ok = rate && (rate > 0) && capacity && (capacity > 0)
      todos << [rate_and_capacity_ok ? TODO_STATUS_DONE : TODO_STATUS_MISSING, _('Enter your rate and capacity'), _('Tell clients about your translation rate and how much translation work you can handle per day.'), { controller: :users, action: :show, id: id, anchor: 'rate_and_capacity' }, true]
      active_items += 1 unless rate_and_capacity_ok

      ta_chats = get_ta_chats
      qualification_status = userstatus == USER_STATUS_QUALIFIED ? TODO_STATUS_DONE : !ta_chats.empty? ? TODO_STATUS_PENDING : TODO_STATUS_MISSING
      todos << [qualification_status,
                !ta_chats.empty? ? _('Complete your practice project') : _('Do basic training'), _('Learn how to use Translation Assistant and become familiar with the system.'), { controller: :users, action: :request_practice_project }, can_do_training?]
      active_items += 1 if count_only ? (qualification_status == count_only) : (qualification_status != TODO_STATUS_DONE)

    end

    [active_items, todos]
  end

  def get_ta_chats
    chats.joins(:revision).where('revisions.kind=?', TA_PROJECT)
  end

  def tl_todo_status(lang_list)
    if lang_list.where(status: TRANSLATOR_LANGUAGE_APPROVED).first
      TODO_STATUS_DONE
    elsif lang_list.where(status: TRANSLATOR_LANGUAGE_REQUEST_REVIEW).first
      TODO_STATUS_PENDING
    else
      TODO_STATUS_MISSING
    end
  end

  # web messages available for this user
  def open_web_messages(extra_sql = '', limit = nil)
    # different cache key based on arguments
    key = method(__method__).parameters.map { |arg| arg[1] }.map { |arg| "#{arg} = #{eval arg.to_s}" }.join(', ')
    # TODO: Caching here makes the its#index api to fail to get newly created ITs 03292017
    # Rails.cache.fetch("#{self.cache_key}/open_web_messages-#{key}", expires_in: CACHE_DURATION) do
    messages = []
    limit = nil # this logic is wrong

    # first, check if this translator has any accepted translation contracts
    accepted_contracts = website_translation_contracts.joins(:website_translation_offer).where('(website_translation_offers.status != ?) AND (website_translation_contracts.status=?)', TRANSLATION_OFFER_SUSPENDED, TRANSLATION_CONTRACT_ACCEPTED)
    accepted_contracts.each do |contract|
      offer = contract.website_translation_offer
      next unless offer.website
      found_messages = offer.website.web_messages.joins(:money_account).where("(web_messages.translation_status = ?)
      AND (((web_messages.visitor_language_id=?) AND (web_messages.client_language_id=?) AND (web_messages.user_id IS NULL))
      OR ((web_messages.visitor_language_id=?) AND (web_messages.client_language_id=?) AND (web_messages.user_id IS NOT NULL)))
      AND (money_accounts.balance >= (web_messages.word_count * ?)) #{extra_sql}", TRANSLATION_NEEDED, offer.from_language_id, offer.to_language_id, offer.to_language_id, offer.from_language_id, contract.amount).limit(limit)
      messages += found_messages
    end

    # Next, check for instant translation jobs
    from_lang_ids = from_languages.collect(&:id)
    to_lang_ids = to_languages.collect(&:id)

    if !from_lang_ids.empty? && !to_lang_ids.empty?
      all_messages = WebMessage.includes(:money_account).where("(web_messages.translation_status = ?)
      AND (((web_messages.visitor_language_id IN (?)) AND (web_messages.client_language_id IN (?)) AND (web_messages.user_id IS NULL))
      OR ((web_messages.visitor_language_id IN (?)) AND (web_messages.client_language_id IN (?)) AND (web_messages.user_id IS NOT NULL)))
      AND (web_messages.owner_type != 'Website') #{extra_sql}", TRANSLATION_NEEDED, from_lang_ids, to_lang_ids, to_lang_ids, from_lang_ids).limit(limit).to_a

      # TODO: use query for this? spetrunin 10/21/2016
      all_messages.delete_if { |m| m.money_account.balance < m.translation_price }

      dialog_ids = {}
      all_messages.each do |message|
        owner = "#{message.owner_type}#{message.owner_id}"
        if (message.owner_type != 'WebDialog') || !dialog_ids.key?(owner)
          messages << message
          dialog_ids[owner] = true
        end
      end
    end

    # Filter web messages that the translator marked as complex
    messages.delete_if do |m|
      unless m.complex_flag_users.nil?
        YAML.load(m.complex_flag_users).include?(id)
      end
    end

    # Filter web messages that are already flagged as too complex
    messages.delete_if(&:complex?)

    # Filter web messages which doesn't have money to be translated
    messages.delete_if { |m| m.client && m.price > m.client.money_account.balance }

    messages
    # end
  end

  def instant_translations
    its = {}
    its[:in_progress] = WebMessage.find_by(translator_id: self.id, translation_status: 3)
    its[:open] = self.open_web_messages
    its
  end

  def expert?
    level == EXPERT_TRANSLATOR
  end

  # TODO: consider splitting this method (creating one query for each type of ManagedWork)
  def open_managed_works
    # cache_key is a Rails method that generates a string based on the record's
    # (or a collection of records) id and updated_at attributes. In case of a
    # collection, it takes the maximum updated_at attribute amongst all records.
    # To invalidate the cache when other associated models are updated, we use
    # "touch: true" in the associations.
    Rails.cache.fetch("#{self.cache_key}/open_managed_works", expires_in: CACHE_DURATION) do
      return [] unless (level == EXPERT_TRANSLATOR) && from_lang_ids.present? && to_lang_ids.present?

      # Website translation projects have two types of managed_works, one associated
      # with website_translation_offer and other associated with revision_language.
      # Here, we only want to display those that are associated with
      # website_translation_offer.

      # Get a list of IDs of WTOs (language pairs) that are "reviewable"
      reviewable_wtos = WebsiteTranslationOffer.reviewable_language_pairs
      # Select only the WTOs with manual translator assignment. The ones with
      # automatic translator assignment should not appear in the "open work"
      # page of all translators, because a specific translator will be assigned
      # as a reviewer. This does not generate any additional queries.
      reviewable_wtos.select! { |wto| wto.automatic_translator_assignment == false }
      reviewable_wto_ids = reviewable_wtos.map(&:id).join(',')
      # Can't be empty (it breaks the SQL query)
      reviewable_wto_ids = 0 if reviewable_wto_ids.empty?

      # Not sure why client_id may not be nil, this criteria is inherited from the old query.
      #
      # managed_work.owner is polymorphic and owner_type can be any of the
      # following: nil, "ResourceLanguage", "RevisionLanguage", "WebMessage",
      # "WebsiteTranslationOffer"
      query = <<-SQL
        SELECT
          -- Select all attributes required by ApplicationHelper#managed_work_links to avoid N+1
          CONCAT_WS ('', text_resources.name, projects.name, websites.name) AS project_name,
          from_language.name AS from_language_name,
          to_language.name AS to_language_name,
          -- Work/project ID to generate a link to the review in the "Open Work" page
          CONCAT_WS ('', resource_languages.text_resource_id, revisions.project_id, wtos.id) AS id_for_link,
          wtos.website_id AS wto_website_id,
          revision_languages.revision_id AS revision_language_revision_id,
          managed_works.id AS managed_work_id,
          managed_works.updated_at,
          managed_works.owner_type
        FROM managed_works
          LEFT OUTER JOIN resource_languages
            ON resource_languages.id = managed_works.owner_id
               AND managed_works.owner_type = 'ResourceLanguage'
          LEFT OUTER JOIN revision_languages
            ON revision_languages.id = managed_works.owner_id
               AND managed_works.owner_type = 'RevisionLanguage'
          LEFT OUTER JOIN revisions
            ON revisions.id = revision_languages.revision_id
               AND revisions.cms_request_id IS NULL
          LEFT OUTER JOIN website_translation_offers AS wtos
            ON wtos.id = managed_works.owner_id
               AND managed_works.owner_type = 'WebsiteTranslationOffer'
          -- The following joins are included exclusively to avoid N+1 at the view
          -- Dependencies for MWs with ResourceLanguage as owners
          LEFT OUTER JOIN text_resources
            ON text_resources.id = resource_languages.text_resource_id
          LEFT OUTER JOIN resource_chats
            ON resource_chats.resource_language_id = resource_languages.id
          LEFT OUTER JOIN users as clients
            ON clients.id = text_resources.client_id
          -- Dependencies for MWs with RevisionLanguage as owners
          LEFT OUTER JOIN projects
            ON projects.id = revisions.project_id
          -- Dependencies for MWs with WebsiteTranslationOffer as owners
          LEFT OUTER JOIN websites
            ON websites.id = wtos.website_id
          -- Dependencies used by multiple types of MWs (more than one owner type)
          LEFT OUTER JOIN languages as from_language
            ON from_language.id = CONCAT_WS('', text_resources.language_id, revisions.language_id, wtos.from_language_id)
          LEFT OUTER JOIN languages as to_language
            ON to_language.id = CONCAT_WS('', resource_languages.language_id, revision_languages.language_id, wtos.to_language_id)
        WHERE managed_works.from_language_id IN (#{self.from_lang_ids.join(',')})
          AND managed_works.to_language_id IN (#{self.to_lang_ids.join(',')})
          AND managed_works.client_id IS NOT NULL
          AND managed_works.translator_id IS NULL
          AND managed_works.owner_id IS NOT NULL
          AND managed_works.owner_type != 'WebMessage'
          AND (
            /* For website translation projects, we don't care about the value
            of `managed_work.active`. In order to know if a WebsiteTranslationOffer
            requires a reviewer or not, we check if it has any "associated"
            cms_requests with `cms_request.review_enabled` set to `true`. For
            that, we use `WebsiteTranslationOffer.reviewable_language_pairs`. */
            (managed_works.owner_type = 'WebsiteTranslationOffer' AND managed_works.owner_id IN (#{reviewable_wto_ids}))
            /* revisions and revision_languages are used in Website translation projects but
            also other types of projects (e.g. bidding projects). We want to display
            managed_works whose owners are revision_languages IF they DON'T belong to
            website translation projects and they were "released to translators" by the
            client (revision.released == 1). I've checked on Feb 21 2018 and there
            are no revision_languages that belong to website translation projects
            with released = 1 (except for 5 records from 2009 and 201N0 which we
            can consider anomalies in the data). That means, if released = 1,
            we can be sure it's not a website project. */
            OR (managed_works.owner_type = 'RevisionLanguage'
                AND revisions.released = 1
                AND managed_works.active IN (#{MANAGED_WORK_ACTIVE}, #{MANAGED_WORK_PENDING_PAYMENT}))
            /* In the previous queries, many of the returned software translation
            reviews generated access denied error when the translator clicked the
            link. This is fixed by the extra criteria in the next line, which
            includes the TextResource authorization criteria from Translator#can_view? */
            OR (managed_works.owner_type = 'ResourceLanguage'
                AND resource_languages.status = #{RESOURCE_LANGUAGE_CLOSED}
                AND (clients.last_login > "#{3.months.ago.utc.to_s(:db)}" OR resource_chats.status = #{RESOURCE_CHAT_ACCEPTED}
                AND managed_works.active IN (#{MANAGED_WORK_ACTIVE}, #{MANAGED_WORK_PENDING_PAYMENT}))
            )
          );
      SQL

      ManagedWork.find_by_sql(query)
    end
  end

  def pending_managed_works
    managed_works.where(
      [
        '(active=?)
         AND (translation_status=?)
         AND (from_language_id IN (?))
         AND (to_language_id IN (?))',
        MANAGED_WORK_ACTIVE,
        MANAGED_WORK_REVIEWING,
        from_lang_ids,
        to_lang_ids
      ]
    )
  end

  def web_message_in_progress
    WebMessage.find_by(translator: self, translation_status: TRANSLATION_IN_PROGRESS)
  end

  def web_messages_for_review(extra_sql = '', limit = nil)
    messages = []
    return [] if level != EXPERT_TRANSLATOR

    if !from_lang_ids.empty? && !to_lang_ids.empty?
      where = ["(web_messages.translation_status = ?) AND (managed_works.translation_status IN (?)) AND (web_messages.translator_id != ?)
      AND (((web_messages.visitor_language_id IN (?)) AND (web_messages.client_language_id IN (?)) AND (web_messages.user_id IS NULL))
      OR ((web_messages.visitor_language_id IN (?)) AND (web_messages.client_language_id IN (?)) AND (web_messages.user_id IS NOT NULL)))
      AND ((managed_works.translator_id IS NULL) OR (managed_works.translator_id = ?)) #{extra_sql}", TRANSLATION_COMPLETE, [MANAGED_WORK_CREATED, MANAGED_WORK_WAITING_FOR_REVIEWER], id, from_lang_ids, to_lang_ids, to_lang_ids, from_lang_ids, id]
      if limit
        all_messages = WebMessage.joins(:managed_work).where(where).includes(:money_account).limit(limit).to_a
      else
        all_messages = WebMessage.joins(:managed_work).where(where).includes(:money_account).to_a
      end

      dialog_ids = {}

      all_messages.delete_if { |m| m.money_account.balance < m.review_price }

      all_messages.each do |message|
        owner = "#{message.owner_type}#{message.owner_id}"
        if (message.owner_type != 'WebDialog') || !dialog_ids.key?(owner)
          messages << message
          dialog_ids[owner] = true
        end
      end
    end

    messages
  end

  def from_lang_ids
    unless @from_lang_ids_cache
      @from_lang_ids_cache = translator_languages.where(["(translator_languages.type = 'TranslatorLanguageFrom') AND (translator_languages.status = #{TRANSLATOR_LANGUAGE_APPROVED})"]).collect(&:language_id)
    end
    @from_lang_ids_cache
  end

  def to_lang_ids
    unless @to_lang_ids_cache
      @to_lang_ids_cache = translator_languages.where(["(translator_languages.type = 'TranslatorLanguageTo') AND (translator_languages.status = #{TRANSLATOR_LANGUAGE_APPROVED})"]).collect(&:language_id)
    end
    @to_lang_ids_cache
  end

  def can_translate(obj)
    if obj.class == ResourceLanguage
      to_languages.include?(obj.language) &&
        from_languages.include?(obj.text_resource.language)
    elsif obj.class == RevisionLanguage
      to_languages.include?(obj.language) &&
        from_languages.include?(obj.revision.language)
    elsif obj.class == WebsiteTranslationOffer
      to_languages.include?(obj.from_language) &&
        from_languages.include?(obj.to_language)
    elsif obj.class == WebMessage
      to_languages.include?(obj.visitor_language) &&
        from_languages.include?(obj.client_language)
    end
  end

  def open_website_translation_offers(extra_sql = '', limit = nil)
    if userstatus == USER_STATUS_PRIVATE_TRANSLATOR
      patron_ids = patrons.collect(&:id)
      res = WebsiteTranslationOffer.joins(:website).where("(website_translation_offers.status=?)
            AND (websites.client_id IN (?)) #{extra_sql}
            AND NOT EXISTS (SELECT * FROM website_translation_contracts WHERE ((website_translation_contracts.website_translation_offer_id=website_translation_offers.id) AND (website_translation_contracts.translator_id=?)))", TRANSLATION_OFFER_OPEN, patron_ids, id).
            order('website_translation_offers.id DESC').limit(limit)
    else
      return [] if from_lang_ids.empty? || to_lang_ids.empty?

      # WebsiteTranslationOffers with automatic translation assignment enabled
      # must be excluded from this query. They always have status
      # TRANSLATION_OFFER_CLOSED (1), so the status criteria excludes them.
      potential_offers =
        WebsiteTranslationOffer.
        joins(:website).
        where("(websites.project_kind != ?)
        AND (websites.anon != 1)
        AND (website_translation_offers.status=?)
        AND (website_translation_offers.from_language_id IN (?))
        AND (website_translation_offers.to_language_id IN (?)) #{extra_sql}
        AND NOT EXISTS (
          SELECT *
          FROM website_translation_contracts
          WHERE ((website_translation_contracts.website_translation_offer_id = website_translation_offers.id)
                 AND (website_translation_contracts.translator_id = ?)))", TEST_CMS_WEBSITE, TRANSLATION_OFFER_OPEN, from_lang_ids, to_lang_ids, id).
        order('website_translation_offers.id DESC')

      added = 0
      res = []
      potential_offers.each do |offer|
        next unless offer.website && offer.website.client && (offer.website.client.userstatus == USER_STATUS_REGISTERED) && (!offer.invitation.blank? || (offer.website.cms_requests.count > 0))
        res << offer
        added += 1
        break if limit && (added >= limit)
      end
    end
    res
  end

  def open_website_translation_work(only_new = false, limit = nil)
    # different cache key based on arguments
    key = method(__method__).parameters.map { |arg| arg[1] }.map { |arg| "#{arg} = #{eval arg.to_s}" }.join(', ')
    Rails.cache.fetch("#{self.cache_key}/open_website_translation_work-#{key}", expires_in: CACHE_DURATION) do
      if (from_lang_ids.empty? || to_lang_ids.empty?) && (userstatus != USER_STATUS_PRIVATE_TRANSLATOR)
        return []
      end

      already_sent_notification_ids = only_new ? sent_notifications.where(['sent_notifications.owner_type = ?', 'CmsRequest']).collect(&:owner_id) : []

      res = []
      found_request_ids = [0]

      accepted_contracts =
        website_translation_contracts.
        joins(:website_translation_offer).
        where(
          ['website_translation_offers.status != ?
           AND website_translation_contracts.status= ?
           AND website_translation_contracts.translator_id = ?',
           TRANSLATION_OFFER_SUSPENDED,
           TRANSLATION_CONTRACT_ACCEPTED,
           self.id]
        )

      paid_cms_request_ids = PendingMoneyTransaction.
                             where(owner_type: 'CmsRequest').
                             pluck(:owner_id)

      return [] unless paid_cms_request_ids.any?

      accepted_contracts.each do |contract|
        offer = contract.website_translation_offer
        website = offer.website
        next unless website && website.client && (website.client.userstatus != USER_STATUS_CLOSED)

        conditions = "cms_requests.id NOT IN (#{found_request_ids.join(',')})
              AND cms_requests.status = #{CMS_REQUEST_RELEASED_TO_TRANSLATORS}
              AND cms_requests.website_id = #{website.id}
              AND cms_requests.language_id = #{offer.from_language_id}
              AND cms_target_languages.status = #{CMS_TARGET_LANGUAGE_CREATED}
              AND cms_target_languages.language_id = #{offer.to_language_id}
              AND (cms_target_languages.translator_id IS NULL OR cms_target_languages.translator_id = #{id})"

        # Only CmsRequests that are already paid for: there is an associated
        # PendingMoneyTransaction. Hence, the amount corresponding to the
        # CmsRequest is already reserved in the client's ICL account hold_sum.
        unless userstatus == USER_STATUS_PRIVATE_TRANSLATOR
          conditions += " AND cms_requests.id IN (#{paid_cms_request_ids.join(',')})"
        end

        if only_new && !already_sent_notification_ids.empty?
          conditions += " AND cms_requests.id NOT IN (#{already_sent_notification_ids.join(',')})"
        end

        found_requests = CmsRequest.joins(:cms_target_languages).where([conditions]).order('cms_requests.id ASC').limit(limit).distinct

        res += found_requests
        found_request_ids += found_requests.collect(&:id)
      end

      res
    end
  end

  def open_text_resource_projects(extra_sql = '', limit = nil)
    # different cache key based on arguments
    key = method(__method__).parameters.map { |arg| arg[1] }.map { |arg| "#{arg} = #{eval arg.to_s}" }.join(', ')
    Rails.cache.fetch("#{self.cache_key}/open_text_resource_projects-#{key}", expires_in: CACHE_DURATION) do
      if userstatus == USER_STATUS_PRIVATE_TRANSLATOR

        return [] if patrons.empty?

        patron_ids = patrons.collect(&:id)

        potential_resource_languages = ResourceLanguage.joins(:text_resource).where(["(text_resources.client_id in (?)) #{extra_sql}", patron_ids]).limit(limit)
      else
        potential_resource_languages = ResourceLanguage.joins(:text_resource).where(["(resource_languages.status=?) AND (text_resources.language_id IN (?)) AND (resource_languages.language_id IN (?)) #{extra_sql}", RESOURCE_LANGUAGE_OPEN, from_lang_ids, to_lang_ids]).order('text_resources.created_at').limit(limit)
      end

      res = []
      potential_resource_languages.each do |resource_language|
        client = resource_language.text_resource.client
        if  client && client.userstatus == USER_STATUS_REGISTERED &&
            (client.last_login && client.last_login > Date.today - 3.months)
          res << resource_language
        end
      end
      res.reverse
    end
  end

  def can_apply_to_resource_translation(resource_language)
    (userstatus == USER_STATUS_PRIVATE_TRANSLATOR) || ((resource_language.status == RESOURCE_LANGUAGE_OPEN) && from_lang_ids.include?(resource_language.text_resource.language_id) && to_lang_ids.include?(resource_language.language_id))
  end

  def need_ta?
    (userstatus == 4) || (!from_languages.empty? && !to_languages.empty?)
  end

  def release_active_web_messages
    # active_messages = active_web_messages
    # unless active_messages.empty?
    #   active_messages.each(&:release_from_hold)
    #   reload
    # end
  end

  # this needs to be called after updating the translator's profile
  def rescan_languages
    all_languages.each { |l| l.update_attributes(scanned_for_translators: 0) }
  end

  def calc_raw_rating

    balance = 0
    money_accounts.each do |money_account|
      balance += (money_account.payments.sum(:amount) || 0)
      balance += money_account.balance
    end

    issues_count = targeted_issues.where(['issues.kind = ?', ISSUE_INCORRECT_TRANSLATION]).count
    bookmarks_count = markings.count

    new_rating = balance - (issues_count * RATING_ISSUE_WEIGHT) + (bookmarks_count * RATING_BOOKMARK_WEIGHT)
    new_rating
  end

  def update_raw_rating
    self.raw_rating = calc_raw_rating
    save
  end

  def update_level
    update_raw_rating
    self.level = raw_rating > MIN_RATING_FOR_EXPERT_TRANSLATOR ? EXPERT_TRANSLATOR : NORMAL_TRANSLATOR
    save
  end

  def self.calculate_ratings

    # first, we need to sort the languages by most popular ones.
    # we'll group translators according to their most popular target language.

    language_popularity = {}
    Language.all.find_each do |lang|
      language_popularity[lang] = lang.translator_languages.length
    end

    updated_cnt = 0

    Translator.all.find_each(&:update_level)

    language_pairs = {}
    Translator.order('users.raw_rating DESC').each do |translator|

      from_languages = translator.from_languages.collect { |fl| [language_popularity[fl], fl] }
      to_languages = translator.to_languages.collect { |tl| [language_popularity[tl], tl] }

      max_froms = -1
      from_language = nil
      from_languages.each do |fl|
        if fl[0] > max_froms
          max_froms = fl[0]
          from_language = fl[1]
        end
      end

      max_tos = -1
      to_language = nil
      to_languages.each do |tl|
        if (tl[0] > max_tos) && (tl[1] != from_language)
          max_tos = tl[0]
          to_language = tl[1]
        end
      end

      next unless from_language && to_language
      languages = "#{from_language.id},#{to_language.id}"
      language_pairs[languages] = [] unless language_pairs.key?(languages)
      language_pairs[languages] << translator
    end

    new_min = 80.0
    new_max = 100.0

    logger.info('UPDATE RATINGS')
    language_pairs.each do |k, translators|

      logger.info("Language pair: #{k.inspect}")
      # pass 1, get max and min
      min_rating = nil
      max_rating = nil

      translators.each do |translator|
        rating = translator.raw_rating
        min_rating = rating if min_rating.nil? || (rating < min_rating)
        max_rating = rating if max_rating.nil? || (rating > max_rating)
      end

      logger.info("max rating: #{max_rating}")
      logger.info("min rating: #{min_rating}")

      # pass 2, normalize the rating for this language
      factor = (new_max - new_min) / (max_rating - min_rating)
      offset = new_min - (min_rating * factor)
      logger.info("factor: #{factor}")
      logger.info("offset: #{offset}")

      incr = (new_max - new_min) / translators.length
      rating = new_max
      logger.info("incr: #{incr}")
      logger.info("offset: #{offset}")

      translators.each do |translator|
        ok = translator.update_attributes(rating: rating)
        translator.reload
        logger.info("Set #{translator.nickname} #{translator.id} rating to #{rating}. result: #{ok}")

        rating -= incr
        updated_cnt += 1
      end
      logger.info('')

    end

    updated_cnt
  end

  def qualified?
    userstatus == USER_STATUS_QUALIFIED
  end

  def qualify
    update_attributes(userstatus: USER_STATUS_QUALIFIED, scanned_for_languages: 0)
  end

  def self.find_by_languages(_userstatus, source_lang_id, target_lang_id, extra_sql = '')
    joins(:translator_language_froms, :translator_language_tos).
      left_joins(:translator_categories).
      where("(users.userstatus = #{USER_STATUS_QUALIFIED})
        AND (translator_languages.status = #{TRANSLATOR_LANGUAGE_APPROVED})
        AND (translator_languages.language_id = #{source_lang_id})
        AND (translator_language_tos_users.status = #{TRANSLATOR_LANGUAGE_APPROVED})
        AND (translator_language_tos_users.language_id = #{target_lang_id}) #{extra_sql}").
      order('users.raw_rating DESC').uniq
  end

  def current_jobs_in_progress
    # count all active projects for this translator
    res = chats.joins(:revision, :bids).where(['(bids.status = ?)', BID_ACCEPTED]).count
    res += resource_chats.where('(status=?) AND (translation_status=?) AND (word_count != 0)', RESOURCE_CHAT_ACCEPTED, RESOURCE_CHAT_PENDING_TRANSLATION).count
    res
  end

  def self.calculate_jobs_in_progress
    Translator.where(['userstatus IN (?)', [USER_STATUS_REGISTERED, USER_STATUS_QUALIFIED]]).find_each do |translator|
      translator.update_attribute(:jobs_in_progress, translator.current_jobs_in_progress)
    end

    nil
  end

  def can_deposit?
    false
  end

  def can_pay?
    false
  end

  def can_view_finance?
    true
  end

  def is_reviewer_of?(revision)
    return false unless revision.is_a? Revision

    !!revision.revision_languages.to_a.find do |rl|
      rl.managed_work.try(:enabled?) && (rl.managed_work.try(:translator) == self)
    end
  end

  def is_allowed_to_withdraw?
    true
  end

  # get chats valid for ta projects
  def get_ta_projects
    chats.joins(:revision).where('revisions.kind=?', TA_PROJECT).order('chats.id DESC').limit(ta_limit)
  end

  def validate_supporter_password(password)
    self.supporter_password == Digest::MD5.hexdigest(password)
  end

  def create_supporter_password
    pass = SecureRandom.base64[0..6]
    self.update_attribute(:supporter_password, Digest::MD5.hexdigest(pass))
    self.update_attribute(:supporter_password_expiration, Time.now + 6.hours)
    pass
  end

  def webta_jobs(what = 'open', page = 1, per = 10, sort = 'id', sort_direction = 'desc', job_id = '')
    valid_sorting_fields = %w(deadline id project_name website_name source_language target_language)
    sort = 'deadline' unless valid_sorting_fields.include?(sort)
    sort_direction = 'desc' unless %w(asc desc).include?(sort_direction)
    per = 10 unless (5..50).cover?(per)
    jobs = get_cms_requests(what, job_id)
    last_page = (jobs.size / per.to_f).ceil
    page = last_page if page.to_i > last_page
    sort_jobs!(jobs, sort, sort_direction)
    page_jobs = Kaminari.paginate_array(jobs).page(page).per(per)

    calculate_and_add_complexity!(page_jobs)
    calculate_job_status!(page_jobs)

    data = page_jobs
    {
      jobs: data,
      pagination: {
        total_pages: data.total_pages,
        current_page: data.current_page,
        prev_page: data.prev_page,
        next_page: data.next_page,
        total_jobs: jobs.size
      }
    }
  end

  def translatable_cms(revision)
    cms = revision.cms_request
    return nil unless cms && cms.xliff_processed
    if cms.status >= CMS_REQUEST_RELEASED_TO_TRANSLATORS && !cms.cms_target_languages.empty? && (cms.cms_target_languages.map(&:translator).include?(self) || cms.revision.revision_languages.map(&:managed_work).flatten.map(&:translator).include?(self))
      cms
    end
  end

  def link_to_webta(cms = nil, type = 'translate')
    if cms
      "#{WEBTA_HOST}/translate/job/#{cms.id}/auth/#{UserToken.create_token(self).token}/service/#{WEBTA_SERVICE}/#{type}"
    else
      "#{WEBTA_HOST}/translate/dashboard/auth/#{UserToken.create_token(self).token}/service/#{WEBTA_SERVICE}"
    end
  end

  def webta_enabled?
    !WEBTA_BETA || self.beta?
  end

  def calculate_and_add_complexity!(jobs)
    return jobs if jobs.blank?

    total_words = jobs.inject(0) do |words, job|
      words + job[:progress_details][:total_words]
    end

    average_words = total_words.to_f / jobs.count.to_f
    smallest_step = 0

    jobs.each do |job|
      ratio = (job[:progress_details][:total_words] - average_words) / average_words
      step = get_step(ratio)
      job[:progress_details][:complexity] = step
      smallest_step = step if step < smallest_step
    end

    jobs.each do |job|
      job[:progress_details][:complexity] += COMPLEXITY_COEFFICIENTS.count - smallest_step
    end

    jobs
  end

  def get_step(ratio)
    multiplier = ratio > 0 ? 1 : -1
    ratio *= multiplier

    COMPLEXITY_COEFFICIENTS.each_with_index do |coefficient, index|
      next if ratio > coefficient
      return index * multiplier
    end

    COMPLEXITY_COEFFICIENTS.count * multiplier
  end

  def calculate_job_status!(jobs)
    return jobs if jobs.blank?
    jobs.sort_by! { |job| job[:deadline] }
    occupied_days = 0
    current_time = Time.zone.now.beginning_of_day.to_i
    jobs.each do |job|
      remaining_days = (job[:deadline] - current_time) / 1.day
      untranslated_words = job[:progress_details][:total_words] - job[:progress_details][:translated_words]
      occupied_days += untranslated_words.to_f / self.capacity
      job[:progress_details][:status] = get_status_code(remaining_days, occupied_days)
    end
    jobs
  end

  def get_status_code(remaining_days, occupied_days)
    return STATUS_CODES[:green] if remaining_days >= occupied_days

    exceeded_days = occupied_days - remaining_days
    exceeded_days >= STATUS_THRESHOLD ? STATUS_CODES[:red] : STATUS_CODES[:yellow]
  end

  def sort_jobs!(jobs, sort, sort_direction)
    sort = sort.to_sym
    # Skipping sort by deadline because jobs already sorted in #calculate_job_status!
    unless sort == :deadline
      case sort
      when :project_name
        jobs.sort_by! { |j| j[:project][:name] }
      when :website_name
        jobs.sort_by! { |j| j[:website][:name] }
      else
        jobs.sort_by! { |j| j[sort] }
      end
    end
    sort_direction == 'desc' ? jobs.reverse! : jobs
  end

  def get_cms_requests(status, job_id)
    Queries::CmsRequests::List::Factory.query_for(id, status, job_id).all_for_webta
  end

  def has_cms_reviews(website)
    managed_work = ManagedWork.where(owner_type: 'WebsiteTranslationOffer',
                                     owner_id: website.website_translation_offers.map(&:id),
                                     translation_status: MANAGED_WORK_REVIEWING,
                                     translator: self)
    managed_work.present?
  end

  def has_cms_jobs(website)
    website.website_translation_contracts.where(translator: self, status: [TRANSLATION_CONTRACT_NOT_REQUESTED, TRANSLATION_CONTRACT_REQUESTED, TRANSLATION_CONTRACT_ACCEPTED]).present?
  end

  def has_on_going_cms_jobs(website)
    sql = 'SELECT * from cms_target_languages as ctl'\
          ' INNER JOIN cms_requests AS cms ON cms.id = ctl.cms_request_id'\
          ' INNER JOIN websites AS web ON web.id = cms.website_id'\
          ' INNER JOIN users as trans ON trans.id = ctl.translator_id' \
          " WHERE ctl.status = #{CMS_TARGET_LANGUAGE_ASSIGNED} AND web.id = #{website.id} AND ctl.translator_id = #{self.id}"
    ActiveRecord::Base.connection.execute(sql).to_a.present?
  end

  def toggle_ta_blocking
    update_attributes(ta_blocked: !ta_blocked?)
    ta_blocked?
  end

  # Exceptions
  class NotFound < JSONError
    def initialize(message)
      @code = TRANSLATOR_NOT_FOUND
      @message = message
    end
  end
end
