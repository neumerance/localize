class Voucher < ApplicationRecord

  validates :code, :amount, :comments, presence: true
  validates :code, uniqueness: true
  validates :comments, length: { maximum: COMMON_NOTE }

  def activate_on_user(client)
    # check user has not activated any coupon.
    raise 'Voucher already activated' if client.vouchers.any?

    # register the voucher activation
    client.vouchers << self

    # add balance to account
    from = RootAccount.find_or_create
    to = client.get_money_account
    MoneyTransactionProcessor.transfer_money(from,
                                             to,
                                             amount,
                                             DEFAULT_CURRENCY_ID,
                                             TRANSFER_VOUCHER)

  end
end
