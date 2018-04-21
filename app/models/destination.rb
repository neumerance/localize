class Destination < ApplicationRecord
  validates :url, url_field: true
  validates :url, :name, presence: true, uniqueness: true
  has_many :visits
  belongs_to :language

  def lang_name
    language ? language.name : 'All languages'
  end
end
