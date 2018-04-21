class Phone < ApplicationRecord
  has_many :phones_users
  has_many :users, through: :phones_users
end
