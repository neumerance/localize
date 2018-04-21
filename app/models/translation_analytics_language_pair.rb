class TranslationAnalyticsLanguagePair < ApplicationRecord
  belongs_to :to_language, class_name: 'Language', foreign_key: 'to_language_id'
  belongs_to :from_language, class_name: 'Language', foreign_key: 'from_language_id'
  has_many :translation_snapshots, -> { order('date ASC') }, dependent: :destroy
  belongs_to :translation_analytics_profile

  validates_presence_of :to_language, :from_language

  DEFAULT_ESTIMATE_RATE = 1000
  UNREALISTIC_WORD_PER_DAY_ESTIMATE = 1500
  RATE_DAYS_LIMIT = 7 # Ignore any snapshot older than this

  def deadline
    self[:deadline] || project_completion
  end

  def estimate_rate
    estimate_time_rate || DEFAULT_ESTIMATE_RATE
  end

  def auto_deadline?
    self[:deadline].nil?
  end

  def finished?
    last_snapshot = translation_snapshots.last
    last_snapshot.translated_words >= last_snapshot.words_to_translate
  end

  def project_completion
    last_snapshot = translation_snapshots.last
    return Date.today unless last_snapshot

    target_amount = last_snapshot.words_to_translate
    current_amount = last_snapshot.translated_words
    missing_amount = target_amount - current_amount

    last_day = Date.today
    days_remaining = (missing_amount / estimate_rate.to_f).ceil

    last_day + days_remaining.days
  end

  def days_with_no_progress
    days_count = 0
    reversed_snapshots = translation_snapshots.reverse
    reversed_snapshots.each_with_index do |snapshot, i|
      break if (i + 1) == reversed_snapshots.size

      if snapshot.translated_words == reversed_snapshots[i + 1].translated_words
        days_count += 1
      else
        break
      end
    end
    days_count
  end

  # 	This method evaluates the translator words output in the last days.
  #
  # 	For this, only the last RATE_DAYS_LIMITs are count, because we consider
  # 	that the older days aren't as important as the last ones for the current rate.
  #
  # 	Also, anything before the first period where there was no work for this translator
  # 	is discarted as it can degrade the translator rate without motive.
  def translator_rate
    days_count = 0
    first_snapshot = nil
    rate = 0
    translation_snapshots.reverse.each_with_index do |snapshot, _i|
      break if snapshot.translation_complete || (days_count == RATE_DAYS_LIMIT)
      days_count += 1
      first_snapshot = snapshot
    end

    if first_snapshot
      translated_words = translation_snapshots.last.translated_words - first_snapshot.translated_words
      rate = translated_words.to_f / days_count.to_f
    end

    rate
  end

  def estimated_completion_date

    snapshot = translation_snapshots.last
    remaining_words = snapshot.words_to_translate - snapshot.translated_words
    remaining_days = remaining_words / translator_rate
    Date.today + remaining_days.ceil.days
  rescue
    Date.today + 1.year

  end

  def print_snapshots
    translation_snapshots.each do |snapshot|
      puts "#{snapshot.date}\t | #{snapshot.translated_words}\t | #{snapshot.words_to_translate}"
    end
    nil
  end
end
