class BidAccount < MoneyAccount
  belongs_to :bid, foreign_key: :owner_id
end
