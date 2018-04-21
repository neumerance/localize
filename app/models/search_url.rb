class SearchUrl < ApplicationRecord
  belongs_to :search_engine
  belongs_to :language
end
