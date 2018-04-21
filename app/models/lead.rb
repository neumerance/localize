class Lead < ApplicationRecord
  belongs_to :advertisement
  belongs_to :user

  validates_presence_of :name, :url
  validates_uniqueness_of :name, :url, :email

end
