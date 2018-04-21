# main class for sotware project
class TextResource < ApplicationRecord

  require 'csv'

  belongs_to :client
  belongs_to :language
  belongs_to :resource_format
  belongs_to :category
  belongs_to :alias, class_name: 'User'

  belongs_to :owner, polymorphic: true

  has_many :messages, as: :owner, dependent: :destroy

  has_many :resource_languages, dependent: :destroy
  has_many :languages, through: :resource_languages

  has_many :resource_uploads, foreign_key: :owner_id, dependent: :destroy
  has_many :resource_translations, foreign_key: :owner_id, dependent: :destroy
  has_many :resource_downloads, foreign_key: :owner_id, dependent: :destroy

  has_many :resource_chats, through: :resource_languages

  has_many :resource_strings, dependent: :destroy
  has_many :unique_resource_strings, -> { where('resource_strings.master_string_id IS NULL') }, foreign_key: :text_resource_id, class_name: 'ResourceString'
  has_many :string_translations, through: :resource_strings

  has_many :resource_stats, dependent: :destroy

  has_one :support_ticket, as: :object

  has_one :testimonial, as: :owner, dependent: :destroy

  validates_presence_of :name, :description, :language_id
  validates_uniqueness_of :name, on: :create
  validate :validate_language_id
  validates :description, length: { maximum: COMMON_NOTE }

  serialize :extra_contexts

  STRING_TRANSLATED = 1
  STRING_UNTRANSLATED = 2
  STRING_REVIEWED = 3
  STRING_PENDING_REVIEW = 4

  include KeywordProjectMethods
  has_many :keyword_projects, through: :resource_languages

  def project_languages
    resource_languages
  end

  def translator_for(language)
    selected_chat = resource_languages.find_by(language_id: language.id).selected_chat
    selected_chat.translator if selected_chat
  end

  def reviewer_for(language)
    mw = resource_languages.find_by(language_id: language.id).try(:managed_work)
    mw.translator if mw && mw.active?
  end

  def validate_language_id
    errors.add(:language_id, 'must be selected') if language_id == 0
  end

  def string_translations_for_language(language)
    string_translations.joins(:resource_string).where(['(resource_strings.master_string_id IS NULL) AND
           (string_translations.language_id=?)', language.id])
  end

  # Stings that are NOT completed nor being translating
  def untranslated_strings(language)
    resource_strings.joins(:string_translations).where(['(resource_strings.master_string_id IS NULL) AND
       (string_translations.status NOT IN (?)) AND
       (string_translations.language_id=?)', [STRING_TRANSLATION_COMPLETE, STRING_TRANSLATION_BEING_TRANSLATED], language.id])
  end

  #  no payment yet
  def unreviewed_strings(language)
    resource_strings.joins(:string_translations).where(['(resource_strings.master_string_id IS NULL) AND
       (string_translations.status IN (?)) AND
       (string_translations.review_status=?) AND
       (string_translations.language_id=?)', [STRING_TRANSLATION_COMPLETE, STRING_TRANSLATION_BEING_TRANSLATED], REVIEW_NOT_NEEDED, language.id])
  end

  # strings ready to review (already funded)
  def pending_review_strings(language)
    resource_strings.joins(:string_translations).where(
      ['(resource_strings.master_string_id IS NULL) AND
       (string_translations.status IN (?)) AND
       (string_translations.review_status IN (?))  AND
       (string_translations.language_id=?)',
       [STRING_TRANSLATION_COMPLETE, STRING_TRANSLATION_BEING_TRANSLATED],
       [REVIEW_PENDING_ALREADY_FUNDED, REVIEW_AFTER_TRANSLATION],
       language.id]
    )
  end

  def contact
    self.alias ? self.alias : client
  end

  def update_version_num
    self.version_num = version_num + 1
    save!
  end

  def self.word_counter(resource_strings, language, plain_text = false)
    res = 0
    asian_language = Language.asian_language_ids.include?(language.id)
    resource_strings.each do |resource_string|
      # TODO: findout why txt is freezed
      txt = plain_text ? resource_string[:text] : resource_string.txt.dup
      string_wc = asian_language ? (txt.length / UTF8_ASIAN_WORDS).ceil : txt.sanitized_split.length
      res += string_wc
    end
    res
  end

  def delete_old_resource_stats(resource_language)
    conditions = "(version_num != #{version_num})"
    if resource_language
      conditions += " OR (resource_language_id = #{resource_language.id}) AND (resource_language_rev != #{resource_language.version_num})"
    end
    resource_stats.where(conditions).find_each { |s| ResourceStat.delete(s.id) }
  end

  def get_count_from_resource_stats(name, resource_language)
    conditions = "(version_num = #{version_num})"
    if resource_language
      conditions += " AND (resource_language_id = #{resource_language.id}) AND (resource_language_rev = #{resource_language.version_num})"
    end
    conditions += " AND (name='#{name}')"

    resource_stat = resource_stats.where(conditions).first
    return resource_stat.count if resource_stat
  end

  def unclear_strings(params)
    resource_strings.where(unclear: true).page(params[:page]).per(params[:per_page])
  end

  def count_words(resource_strings, language, resource_language, plain_text = false, name = nil, pause = nil)
    return 0 if resource_strings.empty?

    # check if there is already a cache entry about this
    if name
      # while we're here, clean old cache entries
      delete_old_resource_stats(resource_language)

      # now, check if there's a valid entry
      count = get_count_from_resource_stats(name, resource_language)

      return count if count
    end

    if pause
    end

    res = TextResource.word_counter(resource_strings, language, plain_text)

    if name && resource_language
      ResourceStat.create(text_resource_id: id,
                          name: name,
                          version_num: version_num,
                          count: res,
                          resource_language_id: resource_language.id,
                          resource_language_rev: resource_language.version_num)
    elsif name
      ResourceStat.create(text_resource_id: id,
                          name: name,
                          version_num: version_num,
                          count: res)
    end

    res
  end

  # @todo Maybe is a good idea to cache this?
  # def translation_completion_old
  #   Rails.cache.fetch("text_resource/#{self.id}/competing_price", expires_in: 1.hour) do
  #     translations = {}
  #     reviews = {}
  #
  #     # @ToDO Ignore strings with master strings...
  #     self.string_translations.each do |st|
  #       translations[[st.resource_string_id, st.language_id]] = st.status
  #       reviews[[st.resource_string_id, st.language_id]] = st.review_status
  #     end
  #
  #     language_ids = languages.collect(&:id)
  #
  #     res = {}
  #     self.resource_languages.each do |rl|
  #       res[rl.language_id] = {
  #         STRING_UNTRANSLATED => 0, # 2
  #         STRING_TRANSLATED => 0, # 1
  #         STRING_REVIEWED => 0, # 3
  #         STRING_PENDING_REVIEW => 0 # 4
  #       }
  #     end
  #
  #     self.unique_resource_strings.each do |rs|
  #       language_ids.each do |language_id|
  #         key = [rs.id, language_id]
  #
  #         # translation status
  #         if translations.key?(key) && (translations[key] == STRING_TRANSLATION_COMPLETE)
  #           res[language_id][STRING_TRANSLATED] += 1
  #         else
  #           res[language_id][STRING_UNTRANSLATED] += 1
  #         end
  #
  #         # REVIEW: status
  #         if reviews.key?(key) && (reviews[key] == REVIEW_COMPLETED)
  #           res[language_id][STRING_REVIEWED] += 1
  #         elsif reviews.key?(key) && (reviews[key] == REVIEW_PENDING_ALREADY_FUNDED)
  #           res[language_id][STRING_PENDING_REVIEW] += 1
  #         end
  #
  #       end
  #     end
  #     res
  #   end
  # end

  def translation_jobs
    ActiveRecord::Base.connection.exec_query("
    SELECT s.language_id, s.status, count(s.status) as count
        FROM text_resources as t
          INNER JOIN resource_strings as r on t.id=r.text_resource_id
          INNER JOIN string_translations as s on r.id=s.resource_string_id
        WHERE t.id=#{self.id}
          AND r.master_string_id is null
        GROUP BY s.language_id, s.status
        ORDER BY `s`.`language_id`  ASC
    ")
  end

  def review_jobs
    ActiveRecord::Base.connection.exec_query("
    SELECT s.language_id, s.review_status, count(s.review_status) as count
        FROM text_resources as t
          INNER JOIN resource_strings as r on t.id=r.text_resource_id
          INNER JOIN string_translations as s on r.id=s.resource_string_id
        WHERE t.id=#{self.id}
          AND r.master_string_id is null
        GROUP BY s.language_id, s.review_status
        ORDER BY `s`.`language_id`  ASC
    ")
  end

  def languages_with_review
    resource_languages.joins(:managed_work, :language).where('managed_works.active = ?', MANAGED_WORK_ACTIVE)
  end

  def unfunded_strings_for_review
    return [] if languages_with_review.empty?
    resource_strings.joins(:string_translations).where(['(resource_strings.master_string_id IS NULL) AND
       (string_translations.status IN (?)) AND
       (string_translations.review_status=?) AND
       (string_translations.language_id IN (?))', [STRING_TRANSLATION_COMPLETE, STRING_TRANSLATION_BEING_TRANSLATED], REVIEW_NOT_NEEDED,
                                                        languages_with_review.pluck(:language_id)])
  end

  def pending_strings_for_review
    return [] if languages_with_review.empty?
    resource_strings.joins(:string_translations).where(
      ['(resource_strings.master_string_id IS NULL) AND
     (string_translations.status IN (?)) AND
     (string_translations.review_status IN (?))  AND
     (string_translations.language_id IN (?))',
       [STRING_TRANSLATION_COMPLETE, STRING_TRANSLATION_BEING_TRANSLATED],
       [REVIEW_PENDING_ALREADY_FUNDED, REVIEW_AFTER_TRANSLATION],
       languages_with_review.pluck(:language_id)]
    )
  end

  def completed?
    return false if resource_strings.empty?
    translation_completed? && review_completed?
  end

  def translation_completed?
    translation_completion.values.sum { |x| x[STRING_UNTRANSLATED] } == 0
  end

  def review_completed?
    (unfunded_strings_for_review.size == 0) && (pending_strings_for_review.size == 0)
  end

  def translation_completion
    Rails.cache.fetch("#{self.cache_key}/translation_completion", expires_in: CACHE_DURATION) do
      translation_status = translation_jobs

      review_status = review_jobs

      res = {}
      self.resource_languages.each do |rl|
        res[rl.language_id] = {
          STRING_UNTRANSLATED => 0, # 2
          STRING_TRANSLATED => 0, # 1
          STRING_REVIEWED => 0, # 3
          STRING_PENDING_REVIEW => 0 # 4
        }
      end

      # translation status
      translation_status.each do |tr|
        next unless res.keys.include?(tr['language_id'])
        if tr['status'] == STRING_TRANSLATION_COMPLETE
          res[tr['language_id']][STRING_TRANSLATED] += tr['count']
        else
          res[tr['language_id']][STRING_UNTRANSLATED] += tr['count']
        end
      end

      # REVIEW: status
      review_status.each do |rr|
        next unless res.keys.include?(rr['language_id'])
        if rr['review_status'] == REVIEW_COMPLETED
          res[rr['language_id']][STRING_REVIEWED] += rr['count']
        elsif rr['review_status'] == REVIEW_PENDING_ALREADY_FUNDED
          res[rr['language_id']][STRING_PENDING_REVIEW] += rr['count']
        end
      end

      res
    end
  end

  def can_create_testimonial?
    self.testimonial.nil? && self.completed?
  end

  def create_testimonial(params)
    raise 'Testimonial already exists' unless self.testimonial.nil?
    raise 'Job not done yet' unless self.completed?
    params[:owner] = self
    Testimonial.create(owner: self,
                       testimonial: params[:testimonial],
                       link_to_app: params[:link_to_app],
                       testimonial_by: params[:testimonial_by],
                       rating: params[:rating])
  end

  def translator_edit_languages(user)
    edit_languages = []
    if user[:type] == 'Translator'
      edit_languages = resource_chats.where(['(resource_chats.translator_id=?) AND (resource_chats.status=?)', user.id, RESOURCE_CHAT_ACCEPTED]).collect { |c| c.resource_language.language }
    end

    managed_works(user).each do |rl|
      edit_languages << rl.language unless edit_languages.include?(rl.language)
    end

    edit_languages
  end

  def prev_string(resource_string, language_ids, conds = [], cond_args = [])
    additional_conds = []
    additional_args = []
    if language_ids && !language_ids.empty?
      additional_conds << '(string_translations.language_id IN (?))'
      additional_args << language_ids
    end

    if resource_string
      additional_conds << '(resource_strings.id < ?)'
      additional_args << resource_string.id
    end

    next_prev_filtered('resource_strings.id DESC', conds + additional_conds, cond_args + additional_args)
  end

  def next_string(resource_string, language_ids, conds = [], cond_args = [])
    additional_conds = []
    additional_args = []
    if resource_string
      additional_conds << '(resource_strings.id > ?)'
      additional_args << resource_string.id
    end

    if language_ids && !language_ids.empty?
      additional_conds << '(string_translations.language_id IN (?))'
      additional_args << language_ids
    end

    next_prev_filtered('resource_strings.id ASC', conds + additional_conds, cond_args + additional_args)
  end

  def next_prev_filtered(order, conds, cond_args)

    conditions = ([conds.join(' AND ')] + cond_args unless conds.empty?)
    resource_strings.joins(:string_translations).where(conditions).order(order).limit(1).first
  end

  def add_blank_translations
    translations = {}
    string_translations.each { |st| translations[[st.resource_string_id, st.language_id]] = st.status }

    language_ids = languages.collect(&:id)

    res = {}
    resource_languages.each { |rl| res[rl.language_id] = { STRING_UNTRANSLATED => 0, STRING_TRANSLATED => 0 } }

    resource_strings.each do |rs|
      language_ids.each do |language_id|
        key = [rs.id, language_id]
        unless translations.key?(key)
          string_translation = StringTranslation.create!(txt: nil, resource_string_id: rs.id, language_id: language_id, status: STRING_TRANSLATION_MISSING)
        end
      end
    end
  end

  def update_original_strings(strings_to_add, resource_upload, use_translations = false)
    context = resource_upload&.orig_filename
    resource_upload_id = resource_upload&.id

    updated_strings_count = 0
    existing_strings_count = 0
    blocked_strings_count = 0
    added_strings_count = 0

    # self.extra_contexts ||= {}

    # check if such context appears in the project. If so, update it. Otherwise, create a new context.

    # cache all resource strings in the project, so that we don't hit the DB for each one

    context_resource_strings_cache = { nil => {} }
    already_added_ids = {}

    resource_strings.each do |resource_string|
      unless context_resource_strings_cache.key?(resource_string.context)
        context_resource_strings_cache[resource_string.context] = {}
      end
      context_resource_strings_cache[resource_string.context][resource_string.token] = resource_string
      already_added_ids[resource_string.txt] = resource_string.id
    end

    resource_strings_cache = context_resource_strings_cache.key?(context) ? context_resource_strings_cache[context] : {}

    # add all the strings from the nil context to the current context
    unless context.nil?
      context_resource_strings_cache[nil].each do |k, v|
        resource_strings_cache[k] = v
      end
    end

    language_ids = resource_languages.collect(&:language_id)

    review_language_ids = []
    resource_languages.each do |resource_language|
      if resource_language.managed_work && (resource_language.managed_work.active == MANAGED_WORK_ACTIVE) && resource_language.managed_work.translator
        review_language_ids << resource_language.language_id
      end
    end

    ResourceString.transaction do
      strings_to_add.each do |string_to_add|
        token = string_to_add[:token]
        txt = if use_translations
                string_to_add[:translation]
              else
                string_to_add[:text]
              end
        comment = string_to_add[:comments]

        string_context = string_to_add[:context] || context
        # self.extra_contexts[string_context] = true

        resource_string = resource_strings_cache[token]
        if resource_string
          if resource_string.txt != txt
            being_translated = resource_string.string_translations.where(['
                (string_translations.status=?) OR
                ((string_translations.review_status IN (?)) AND
                  (string_translations.language_id IN (?)))',
                                                                          STRING_TRANSLATION_BEING_TRANSLATED, [REVIEW_AFTER_TRANSLATION, REVIEW_PENDING_ALREADY_FUNDED], review_language_ids]).first
            if being_translated
              blocked_strings_count += 1
            else
              resource_string.update_attributes(txt: txt, comment: comment)
              resource_string.string_translations.each do |st|
                if st.status == STRING_TRANSLATION_COMPLETE
                  st.update_attributes(status: STRING_TRANSLATION_NEEDS_UPDATE)
                end
              end
              updated_strings_count += 1
            end
          else
            existing_strings_count += 1
          end
        else
          # only set the master_string if we're ignoring duplicates
          master_string_id = ignore_duplicates == 1 ? already_added_ids[txt] : nil

          # if a master string was found, trace it all the way back to the original (without a master string)
          if master_string_id
            master_string = ResourceString.find(master_string_id)
            while master_string.master_string
              master_string = master_string.master_string
            end
            master_string_id = master_string.id
          end

          if token.length > 255
            Rails.logger.info "TOKEN IS LONGER THAN PERMITTED: #{token}"
            # TODO: should we use validation for token length? spetrunin 24/10/2016
            token = token[0, 255]
          end

          resource_string = ResourceString.new(
            context: string_context,
            token: token,
            txt: txt,
            comment: comment,
            master_string_id: master_string_id,
            resource_upload_id: resource_upload_id,
            word_count: txt.sanitized_split.length
          )

          # check for max_length argument
          unless comment.blank?
            ml_idx = comment.index('icl_max_langth=')
            if ml_idx
              ml_idx += 'icl_max_langth='.length
              ml_end_idx = comment.index('!', ml_idx)
              if ml_end_idx
                val = comment[ml_idx...ml_end_idx].to_i
                resource_string.max_width = val if val > 50
              end
            end
          end

          resource_string.text_resource = self
          if resource_string.save
            added_strings_count += 1

            # remember in the cache too
            resource_strings_cache[token] = resource_string
            unless already_added_ids.key?(txt)
              already_added_ids[txt] = resource_string.id
            end

            # add blank translations in all languages
            language_ids.each do |language_id|
              Rails.logger.info "Saving RS  #{resource_string.token}@#{resource_string.context}: #{resource_string.txt} for language #{language_id}"
              string_translation = StringTranslation.create!(language_id: language_id, txt: nil, resource_string_id: resource_string.id, status: STRING_TRANSLATION_MISSING)
            end
          end
        end
      end
    end

    update_version_num
    save!

    [updated_strings_count, existing_strings_count, added_strings_count, blocked_strings_count]
  end

  def translation_complete(language)
    # 1. locate the chat
    rl = resource_languages.where(language_id: language.id).first
    return false unless rl

    selected_chat = rl.selected_chat
    return false unless selected_chat

    selected_chat.need_to_declare_as_complete
  end

  def can_delete?
    resource_chats.where(resource_chats: { status: RESOURCE_CHAT_ACCEPTED }).count == 0
  end

  def managed_works(user)
    unless @managed_works
      @managed_works = user[:type] == 'Translator' ? user.managed_works.where(['(active=?) AND (owner_type=?) AND (owner_id IN (?))', MANAGED_WORK_ACTIVE, 'ResourceLanguage', resource_languages.collect(&:id)]).collect(&:owner) : []
    end

    @managed_works
  end

  def get_amount_for(param)
    if param.class == ResourceChat
      get_amount_for_resource_chat(param)
    else
      raise "Can't get_amount_for this class"
    end
  end

  def get_amount_for_resource_chat(resource_chat)
    resource_chat.resource_language.cost
  end

  def update_comments(uploaded_strings)
    all_strings = resource_strings
    uploaded_strings.each do |uploaded_string|
      string = all_strings.find_by(token: uploaded_string[:token])
      next unless string && string.txt
      if uploaded_string[:comments]
        string.comment = uploaded_string[:comments]
        string.save
      end
    end
  end

  def add_languages(languages_ids)
    return nil if languages_ids.empty?

    languages_ids.each do |language_id|
      found = resource_languages.find_by(language_id: language_id)
      next if found
      available_language = AvailableLanguage.find_by(from_language_id: self.language_id, to_language_id: language_id)
      translation_amount = available_language ? available_language.price_for(client) : WebMessage.price_per_word_for(client)
      resource_language = ResourceLanguage.new(language_id: language_id, notified: 0, translation_amount: translation_amount)
      resource_language.text_resource = self
      resource_language.save!

      # add translation review for that language
      managed_work = ManagedWork.new(active: MANAGED_WORK_ACTIVE,
                                     translation_status: MANAGED_WORK_CREATED,
                                     from_language_id: self.language_id,
                                     to_language_id: language_id,
                                     client: client,
                                     owner: resource_language,
                                     notified: 0)
      managed_work.save!
    end

    add_blank_translations
    update_version_num

    reload
  end

  # If a file is uploaded into a software project and some strings already
  # exists, but the file has a different name AND the "ignore duplicated" option
  # is NOT choosen, the string is NOT marked as duplicated, but added as NEW.
  # Client has to pay twice for this. This method mark those strings as duplicated
  def locate_and_fix_duplicated_strings

    transaction do
      handled_ids = []
      resource_strings.each do |rs|
        next if handled_ids.include? rs.id
        next if rs.master_string
        next unless rs.duplicates.empty?

        duplicates = resource_strings.where(token: rs.token, txt: rs.txt)
        translations = Hash[duplicates.map(&:string_translations).flatten.select(&:txt).map { |x| [x.language_id, x] }]

        master_string = duplicates.select { |x| !x.duplicates.empty? }.first
        master_string = duplicates.first unless master_string

        duplicates.each do |d|
          d.update_attribute :master_string, master_string unless d == master_string
          d.string_translations.each do |st|
            next unless translations[st.language_id]
            st.txt = translations[st.language_id].txt
            st.status = translations[st.language_id].status
            st.save!
          end
          handled_ids << d.id
        end
      end
    end

    true
  end

  def fix_yaml(sts = true)
    rs = self.resource_strings.where("txt like '---%'")
    rs.each do |r|
      begin
        ch = YAML.load(r.txt)
        ch = ch[0..-4] if ch != r.txt && ch.ends_with?('---')
        ch = nil if ch == r.txt || !r.txt.ends_with?("\n")
        r.update_attribute(:txt, ch) if ch
        if sts
          r.string_translations.where("txt like '---%'").find_each do |st|
            c = YAML.load(st.txt)
            c = c[0..-4] if c != st.txt && ch.ends_with?('---')
            c = nil if c == st.txt
            st.update_attribute(:txt, c) if c
          end
        end
      rescue
        next
      end
    end
  end

  # this is to fix those text resource with no language the causes the app to crash in some pages
  def self.fix_text_resource_with_no_language
    language = Language.where(name: 'English').first
    trs = self.where(language_id: 0)
    CSV.open(Rails.root.join('..', "#{Time.now.to_i}_fixed_broken_text_resource.csv"), 'wb') do |csv|
      csv << %w(id value)
      trs.each do |tr|
        puts "Backing up text resource: #{tr.id}"
        csv << [tr.id, tr.language_id]
      end
    end
    trs.update_all(language_id: language.id)
  end

  def bom_enabled?
    !!self.add_bom
  end

  # This method resets the status of the project like just accepted translators applications. Useful for development
  def reset!
    raise 'Not Intended for production' if Rails.env.production?

    self.resource_languages.each { |rl| rl.money_account.destroy }
    self.string_translations.update_all status: 3, review_status: 0
    self.resource_stats.destroy_all
    self.resource_chats.each { |rc| rc.ua :word_count, 0 }
  end

end
