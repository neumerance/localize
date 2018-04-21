class Withdrawal < ApplicationRecord
  has_many :mass_payment_receipts, dependent: :destroy
end
