class CampaingTrack < ApplicationRecord
  belongs_to :project, polymorphic: true
  belongs_to :from_language, class_name: 'Language', foreign_key: 'from_language_id'
  belongs_to :to_language, class_name: 'Language', foreign_key: 'to_language_id'
  serialize :extra_info
end
