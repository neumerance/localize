class CaptchaKey < ApplicationRecord
  belongs_to :client
  validates_presence_of :key
  validates_uniqueness_of :key, scope: 'client_id'
end
