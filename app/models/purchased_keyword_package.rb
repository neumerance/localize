class PurchasedKeywordPackage < ApplicationRecord
  belongs_to :keyword_project
  has_many :keywords
  belongs_to :keyword_package

  validates_presence_of :price, :remaining_keywords
end
