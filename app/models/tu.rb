class Tu < ApplicationRecord
  belongs_to :client
  belongs_to :translator, touch: true
  belongs_to :from_language, class_name: 'Language', foreign_key: :from_language_id
  belongs_to :to_language, class_name: 'Language', foreign_key: :to_language_id
  belongs_to :owner, polymorphic: true
end
