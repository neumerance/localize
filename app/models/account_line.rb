class AccountLine < ApplicationRecord
  belongs_to :account, polymorphic: true
  belongs_to :money_transaction
end
