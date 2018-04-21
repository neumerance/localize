class HelpGroup < ApplicationRecord
  has_many :help_placements
  has_many :help_topics, through: :help_placement

  validates :name, :order, presence: true, uniqueness: true
end
