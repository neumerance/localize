class Cat < ApplicationRecord
  has_many :cats_users
  has_many :users, through: :cats_users
end
