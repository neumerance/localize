class SiteNotice < ApplicationRecord

  validates :txt, presence: true
  validates :active, presence: true
  validate :valid_start_time
  validate :valid_end_time
  validates :txt, length: { maximum: COMMON_NOTE }

  def self.all_active
    curtime = Time.now
    SiteNotice.where('(active=1) AND (start_time <= ?) AND (end_time >= ?)', curtime, curtime)
  end

  def is_active?
    curtime = Time.now
    (active == 1) && (start_time <= curtime) && (end_time >= curtime)
  end

  private

  def valid_start_time
    errors.add(:start_time, 'Should not be a past date.') if start_time < (Time.now - 1.minute)
  end

  def valid_end_time
    errors.add(:end_time, 'Should not behind or equal the start date.') if end_time <= start_time
  end

  def valid_active_value
    errors.add(:active, 'Valid value is 0 or 1 only.') if active > 1
  end
end
