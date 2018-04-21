class TaxAccount < MoneyAccount
  def self.find_or_create
    find_or_create_by(currency_id: DEFAULT_CURRENCY_ID)
  end
end
