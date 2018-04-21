class Vacation < ApplicationRecord
  belongs_to :user

  validates :beginning, :ending, presence: true
  validates :ending, uniqueness: { scope: [:user_id, :beginning], message: _('Vacations could not overlap') }

  validate :time_in_the_past, on: [:create, :update]
  validate :proper_time_interval
  validate :do_not_conflict

  scope :overlaps, ->(start_date, end_date, this) do
    stmt = ['(DATEDIFF(beginning, ?) * DATEDIFF(?, ending)) >= 0', 'user_id = ?']
    where = [stmt.join(' AND '), end_date, start_date, this.user]
    unless this.id.nil?
      stmt << 'id NOT IN (?)'
      where << this.id
      where[0] = stmt.join(' AND ')
    end
    where(where)
  end

  def status
    curtime = Time.zone.now
    if ending <= curtime
      return _('Completed')
    elsif beginning <= curtime
      return '<span class="warning">' + _('In progress') + '</span>'
    else
      return _('Planned')
    end
  end

  protected

  def do_not_conflict
    if Vacation.overlaps(beginning, ending, self).any?
      errors.add(:base, _('Vacations could not overlap'))
    end
  end

  def proper_time_interval
    if ending < beginning
      errors.add(:base, _('End time cannot be before the beginning time'))
    end
  end

  def time_in_the_past
    curtime = Time.zone.now
    if ending < curtime || beginning < curtime
      errors.add(:base, _('You cannot create a vacation notice for the past'))
    end
  end
end
