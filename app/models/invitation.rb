class Invitation < ApplicationRecord
  belongs_to :normal_user
  validates_presence_of :name, :message
  validates :message, length: { maximum: COMMON_NOTE }
end
