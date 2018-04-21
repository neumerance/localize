require File.dirname(__FILE__) + '/../test_helper'

class MoneyTransactionProcessorTest < ActiveSupport::TestCase
  #  #  fixtures :all

  def test_transaction_no_fees
    from = users(:amir).money_accounts.first
    to = users(:orit).money_accounts.first
    amount = 500
    fee = 0
    op_code = 3
    assert_difference('from.reload.balance', -amount) do
      assert_difference('to.reload.balance', amount) do
        MoneyTransactionProcessor.transfer_money(from, to, amount, DEFAULT_CURRENCY_ID, op_code)
      end
    end
  end

  def test_transaction_with_fee
    from = users(:amir).money_accounts.first
    to = users(:orit).money_accounts.first
    amount = 500
    fee = 0.1
    op_code = 3
    assert_difference('from.reload.balance', -amount) do
      assert_difference('to.reload.balance', amount * (1 - fee)) do
        assert_difference('RootAccount.find_or_create.balance', fee) do
          MoneyTransactionProcessor.transfer_money(from, to, amount, DEFAULT_CURRENCY_ID, op_code)
        end
      end
    end
  end

  def test_transaction_with_fee_and_affiliate
    from = users(:amir).money_accounts.first
    to = users(:orit).money_accounts.first
    affiliate = users(:guy)
    amount = 500
    fee = 0.1
    op_code = 3
    assert_difference('from.reload.balance', -amount) do
      assert_difference('to.reload.balance', amount * (1 - fee)) do
        assert_difference('RootAccount.find_or_create.balance', fee * AFFILIATE_COMMISSION_RATE) do
          assert_difference('affiliate.money_accounts.first.reload.balance', fee * (1 - AFFILIATE_COMMISSION_RATE)) do
            MoneyTransactionProcessor.transfer_money(from, to, amount, DEFAULT_CURRENCY_ID, op_code, fee, affiliate)
          end
        end
      end
    end
  end

end
