class SentNotification < ApplicationRecord
  belongs_to :owner, polymorphic: true
  belongs_to :user

  validates_presence_of :user_id
end
