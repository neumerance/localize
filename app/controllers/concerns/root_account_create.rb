module RootAccountCreate
  def find_or_create_root_account(currency_id)
    # look for the translator account in that currency
    account = RootAccount.where(currency_id: currency_id).first
    # if the root doesn't yet have an account in this currency, lets create it now
    unless account
      account = RootAccount.new(currency_id: currency_id)
      account.save!
    end
    account
  end
end
