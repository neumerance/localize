class RevisionLanguage < ApplicationRecord
  include KeywordProjectLanguage
  keyword_language_associations

  belongs_to :revision
  belongs_to :language
  has_many :bids, dependent: :destroy

  has_many :valid_bids,  -> { where.not(status: BID_CANCELED) }, class_name: 'Bid'
  has_one :selected_bid, -> { where('won = 1') },                class_name: 'Bid'
  has_many :open_bids,   -> { where(status: BID_GIVEN) },        class_name: 'Bid'

  has_many :chats, through: :bids
  has_many :reminders, as: :owner, dependent: :destroy
  has_one :managed_work, as: :owner, dependent: :destroy

  has_many :issues, as: :owner, dependent: :destroy

  before_destroy :cleanup
  def cleanup
    return false if open_bids.any? || selected_bid
    bids.destroy_all
  end

  def translator
    selected_bid.chat.translator if selected_bid
  end

  def set_reviewer(reviewer)
    unless managed_work
      self.managed_work = ManagedWork.new(active: MANAGED_WORK_PENDING_PAYMENT)
      save!

      # If the revision is a part of a Website Translation project, update the
      # cms_request.review_enabled attribute.
      revision.cms_request&.update(review_enabled: true)
    end
    managed_work.update_attribute :translator_id, reviewer.id
  end

  def project
    revision
  end

  def project_name
    revision.project.name
  end

  def delete_reminders(event)
    bids.each do |bid|
      bid.reminders.each do |reminder|
        if reminder.event == event
          bid.reminders.delete(reminder)
          reminder.destroy
        end
      end
    end
  end

  def can_enable_review?
    managed_work && managed_work.disabled?
  end

  def can_disable_review?
    selected_bid.nil? ||
      (managed_work && !managed_work.has_translator?) ||
      (managed_work && managed_work.pending_payment?) ||
      # This last case is when the translator is working, so reviewer couldn't start
      # the work yet
      (managed_work && managed_work.active? && selected_bid.status == BID_ACCEPTED)
  end

  def completed_percentage
    if selected_bid
      last_version = revision.versions.where('by_user_id=?', selected_bid.chat.translator_id).order('id DESC').first
      if last_version
        stats = last_version.get_stats # you can use last_version.get_human_stats
        done_sentences = 0
        total_sentences = 0
        if stats && stats.key?(STATISTICS_SENTENCES)
          if stats[STATISTICS_SENTENCES].key?(language_id)
            stt = stats[STATISTICS_SENTENCES][language_id]
            done_sentences = stt.key?(WORDS_STATUS_DONE_CODE) ? stt[WORDS_STATUS_DONE_CODE] : 0
            stt.each { |_status, count| total_sentences += count }
          elsif stats[STATISTICS_SENTENCES].key?(revision.language_id)
            stt = stats[STATISTICS_SENTENCES][revision.language_id]
            stt.each { |_status, count| total_sentences += count }
          end
        end

        if total_sentences != 0
          return (100.0 * done_sentences / total_sentences).to_i
        else
          return 100
        end
      end
    end
    0

  end

  def assign_translator(t)
    # not right
    c = selected_chat
    c.translator_id = t
    c.save
  end

  def unassign_translator
    b = selected_bid
    b.won = nil
    b.save
  end

  def unfinished_bids
    Bid.where('(revision_language_id = ?) AND (NOT status in (?))', id, [BID_REFUSED, BID_CANCELED, BID_TERMINATED])
  end

  def get_client_id
    managed_work.client_id
  end

  def missing_amount_for_auto_accept
    required_amount = 0
    if revision.auto_accept_amount && (revision.auto_accept_amount > 0)
      balance = revision.project.client.find_or_create_account(revision.max_bid_currency).balance

      project_cost = revision.auto_accept_amount
      if [TA_PROJECT, SIS_PROJECT].include? revision.kind
        lang = case revision.kind
               when TA_PROJECT
                 revision.language
               when SIS_PROJECT
                 # This is a little bit nonsense, why use the first revision_language if we are already on a rev_lang?
                 Language.find(revision.revision_languages.first.language_id)
               end

        project_cost *= revision.lang_word_count(lang)
      end

      if managed_work && (managed_work.active == MANAGED_WORK_PENDING_PAYMENT)
        review_price_percentage = revision.from_cms? ? REVIEW_PRICE_PERCENTAGE : 0.5
        project_cost *= 1 + review_price_percentage
      end

      required_amount = project_cost - balance
      required_amount = 0 if required_amount < 0
    end

    required_amount.ceil_money
  end
end
