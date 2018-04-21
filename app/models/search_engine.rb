class SearchEngine < ApplicationRecord
  has_many :search_urls, dependent: :destroy
end
