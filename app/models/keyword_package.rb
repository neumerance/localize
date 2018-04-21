class KeywordPackage < ApplicationRecord
  has_many :purchased_keyword_packages

  def reuse_package?
    price == 0 && keywords_number == 0
  end

  def self.reuse_package
    find_by(price: 0, keywords_number: 0)
  end

end
