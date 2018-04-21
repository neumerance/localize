module RefundCredit
  def refund_resource_language_leftover_credit(resource_language)
    transferred = 0
    resource_language.money_accounts.each do |account|
      next unless account.balance >= 0.01
      transferred += account.balance
      client_account = resource_language.text_resource.client.find_or_create_account(account.currency_id)
      MoneyTransactionProcessor.transfer_money(account, client_account, account.balance, account.currency_id, TRANSFER_REFUND_FOR_RESOURCE_TRANSLATION)
    end

    transferred
  end
end
