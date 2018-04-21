class HelpTopic < ApplicationRecord
  has_many :help_placements, dependent: :destroy
  has_many :help_groups, through: :help_placement

  validates :url, :title, :summary, :display, presence: true
  validates :url, url_field: true
end
