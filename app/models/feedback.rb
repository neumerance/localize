class Feedback < ApplicationRecord
  belongs_to :owner, polymorphic: true
  validates_presence_of :rating

  belongs_to :from_language, class_name: 'Language', foreign_key: 'from_language_id'
  belongs_to :to_language, class_name: 'Language', foreign_key: 'to_language_id'
  belongs_to :translator, touch: true
end
