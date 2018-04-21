class PhonesUser < ApplicationRecord
  belongs_to :user
  belongs_to :phone
end
