class Bookmark < ApplicationRecord
  belongs_to :user
  belongs_to :resource, polymorphic: true

  validates_length_of :note, maximum: 750

  validate :user_has_money

  def name
    if resource_type == 'User'
      resource.full_name
    else
      'unknown object'
    end
  end

  private

  def user_has_money
    if user.is_a?(Client) && resource.is_a?(Translator)
      if user.money_accounts.inject(0) { |a, b| a + b.account_lines.count } == 0
        errors.add(:no_money_transaction, 'You need to have a money transaction to be able to bookmark a translator')
      end
    end
  end

end
