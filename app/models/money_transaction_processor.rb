#   To refund:
#     MoneyTransactionProcessor.transfer_money(from, to, amount, DEFAULT_CURRENCY_ID, TRANSFER_GENERAL_REFUND)
#
#   Transfer types:
#     TRANSFER_DEPOSIT_TO_BID_ESCROW = 1
#     TRANSFER_PAYMENT_FROM_BID_ESCROW = 2
#     TRANSFER_REFUND_FROM_BID_ESCROW = 3
#     TRANSFER_DEPOSIT_FROM_EXTERNAL_ACCOUNT = 4
#     TRANSFER_PAYMENT_TO_EXTERNAL_ACCOUNT = 5
#     TRANSFER_REVERSAL_OF_PAYMENT_TO_EXTERNAL_ACCOUNT = 6
#     TRANSFER_FEE_FROM_TRANSLATOR = 7 #is not used
#     TRANSFER_PAYMENT_FOR_INSTANT_TRANSLATION = 8
#     TRANSFER_PAYMENT_FOR_TA_RENTAL = 9
#     TRANSFER_DEPOSIT_TO_RESOURCE_TRANSLATION = 10 # only translation
#     TRANSFER_PAYMENT_FROM_RESOURCE_TRANSLATION = 11 # payment for the translation
#     TRANSFER_REFUND_FOR_RESOURCE_TRANSLATION = 12 # canceled translation
#     TRANSFER_PAYMENT_FROM_RESOURCE_REVIEW = 15 # payment for the review
#     TRANSFER_DEPOSIT_TO_RESOURCE_TRANSLATION_WITH_REVIEW = 17 # translation with review
#     TRANSFER_DEPOSIT_TO_RESOURCE_REVIEW = 18 # only review
#     TRANSFER_DEPOSIT_TO_PROJECT_REVIEW = 20
#     TRANSFER_DEPOSIT_FOR_SERVICE_WORK = 22 # withdrawal to root account for service work
#     TRANSFER_GENERAL_REFUND = 23
#     TRANSFER_PAYMENT_FROM_KEYWORD_LOCALIZATION = 24
#     TRANSFER_DEPOSIT_TO_RESOURCE_TRANSLATION_WITH_REVIEW_AND_KEYWORDS = 25
#     TRANSFER_DEPOSIT_TO_RESOURCE_REVIEW_WITH_KEYWORDS = 26
#     TRANSFER_DEPOSIT_TO_RESOURCE_KEYWORDS = 27
#     TRANSFER_REUSE_KEYWORD = 28
#     TRANSFER_MANUAL_TO_SYSTEM_ACCOUNT = 29
#     TRANSFER_TAX_RATE = 30
#     TRANSFER_VOUCHER = 3

MUTEX_FILE_PATH = '/tmp/icl_mutext_transfer_money'.freeze
class MoneyTransactionProcessor

  # Called from:
  #   two_checkout
  #   WebMessage#complete_translation
  #   Webmessage#review_completed
  #   bid#pay_translator
  #   bid#auto_accept
  #   ... and probably more places
  def self.transfer_money(from, to, amount, _currency_id, operation_code, fee_rate = 0, affiliate_user = nil, attribute = :balance, owner = nil)
    File.open(MUTEX_FILE_PATH, 'w') unless File.exist?(MUTEX_FILE_PATH)
    mutex = File.new(MUTEX_FILE_PATH, 'r+')
    begin
      mutex.flock(File::LOCK_EX)
      root_account = RootAccount.find_or_create
      affiliate_account = affiliate_user && affiliate_user.find_or_create_account(DEFAULT_CURRENCY_ID)

      # Calculate values
      curtime = Time.now
      fee = amount * fee_rate
      net_amount = amount - fee
      if affiliate_user
        affiliate_fee = fee * AFFILIATE_COMMISSION_RATE
        root_fee = fee * (1 - AFFILIATE_COMMISSION_RATE)
      else
        root_fee = fee
      end

      # Update account values
      if (attribute == :balance) && from.has_balance? && from.balance < amount
        raise NotEnoughFunds.new(from, amount)
      end

      MoneyAccount.transaction do
        if from.has_balance?
          StaleObjHandler.retry { from.update_attributes!(attribute => from.send(attribute) - amount) }
        end
        if to.has_balance?
          StaleObjHandler.retry { to.update_attributes!(balance: to.balance + net_amount) }
        end

        if fee != 0
          StaleObjHandler.retry do
            root_account.update_attributes! balance: root_account.balance + root_fee
          end
          if affiliate_user
            StaleObjHandler.retry do
              affiliate_account.update_attributes! balance: (affiliate_account.balance + affiliate_fee)
            end
          end
        end
      end

      # Money Transaction
      money_transaction = MoneyTransaction.new(amount: amount,
                                               fee: fee,
                                               fee_rate: FEE_RATE,
                                               currency_id: DEFAULT_CURRENCY_ID,
                                               chgtime: curtime,
                                               status: TRANSFER_COMPLETE,
                                               affiliate_account_id: affiliate_user && affiliate_account.id,
                                               operation_code: operation_code)
      money_transaction.source_account = from
      money_transaction.target_account = to
      money_transaction.owner = owner
      money_transaction.save!

      # From account line
      if from.has_balance?
        AccountLine.transaction do
          last_balance = from.reload.account_lines.last.try(:balance) || from.balance
          from_account_line = AccountLine.new(balance: last_balance - amount, chgtime: curtime)
          from_account_line.account = from
          from_account_line.money_transaction = money_transaction
          from_account_line.save!
        end
      end

      # To account line
      if to.has_balance?
        AccountLine.transaction do
          last_balance = to.reload.account_lines.last.try(:balance) || to.balance - net_amount
          to_account_line = AccountLine.new(balance: last_balance + net_amount, chgtime: curtime)
          to_account_line.account = to
          to_account_line.money_transaction = money_transaction
          to_account_line.save!
        end
      end

      # Root account line
      if fee != 0
        AccountLine.transaction do
          last_balance = root_account.reload.account_lines.last.try(:balance) || root_account.balance - root_fee
          fee_account_line = AccountLine.new(balance: last_balance + root_fee, chgtime: curtime)
          fee_account_line.account = root_account
          fee_account_line.money_transaction = money_transaction
          fee_account_line.save!
        end
      end

      # Affiliate account line
      if (fee != 0) && affiliate_account
        AccountLine.transaction do
          last_balance = affiliate_account.reload.account_lines.last.try(:balance) || affiliate_account.balance - affiliate_fee
          affiliate_account_line = AccountLine.new(balance: last_balance + affiliate_fee, chgtime: curtime)
          affiliate_account_line.account = affiliate_account
          affiliate_account_line.money_transaction = money_transaction
          affiliate_account_line.save!
        end
      end

      money_transaction
    ensure
      mutex.flock(File::LOCK_UN)
    end
  end

  def self.transfer_money_fixed_fee(from, to, amount, operation_code, fee)
    File.open(MUTEX_FILE_PATH, 'w') unless File.exist?(MUTEX_FILE_PATH)
    mutex = File.new(MUTEX_FILE_PATH, 'r+')
    begin
      mutex.flock(File::LOCK_EX)
      root_account = RootAccount.find_or_create

      # Calculate values
      curtime = Time.now
      net_amount = if from.is_a? UserAccount
                     amount + fee
                   else
                     amount - fee
                   end
      root_fee = fee

      # Update account values
      if from.has_balance? && from.balance.floor_money < net_amount.floor_money
        raise NotEnoughFunds.new(from, net_amount)
      end

      attribute = :balance
      MoneyAccount.transaction do
        if from.has_balance?
          StaleObjHandler.retry { from.update_attributes!(attribute => from.send(attribute) - net_amount) }
        end
        if to.has_balance?
          StaleObjHandler.retry { to.update_attributes!(balance: to.balance + net_amount) }
        end

        if fee != 0
          StaleObjHandler.retry do
            root_account.update_attributes! balance: root_account.balance + root_fee
          end
        end
      end

      # Money Transaction
      money_transaction = MoneyTransaction.new(amount: net_amount,
                                               fee: fee,
                                               currency_id: DEFAULT_CURRENCY_ID,
                                               chgtime: curtime,
                                               status: TRANSFER_COMPLETE,
                                               operation_code: operation_code)
      money_transaction.source_account = from
      money_transaction.target_account = to
      money_transaction.save!

      # From account line
      if from.has_balance?
        AccountLine.transaction do
          last_balance = from.reload.account_lines.last.try(:balance) || from.balance
          from_account_line = AccountLine.new(balance: last_balance - net_amount, chgtime: curtime)
          from_account_line.account = from
          from_account_line.money_transaction = money_transaction
          from_account_line.save!
        end
      end

      # To account line
      if to.has_balance?
        AccountLine.transaction do
          last_balance = to.reload.account_lines.last.try(:balance) || to.balance - net_amount
          to_account_line = AccountLine.new(balance: last_balance + net_amount, chgtime: curtime)
          to_account_line.account = to
          to_account_line.money_transaction = money_transaction
          to_account_line.save!
        end
      end

      # Root account line
      if fee != 0
        AccountLine.transaction do
          last_balance = root_account.reload.account_lines.last.try(:balance) || root_account.balance - root_fee
          fee_account_line = AccountLine.new(balance: last_balance + root_fee, chgtime: curtime)
          fee_account_line.account = root_account
          fee_account_line.money_transaction = money_transaction
          fee_account_line.save!
        end
      end
      money_transaction
    ensure
      mutex.flock(File::LOCK_UN)
    end
  end

  class NotEnoughFunds < StandardError
    def initialize(from_account, amount)
      @message = "Transfer Money: Not enough funds on account ##{from_account.id} with balance $#{from_account.balance} to withdraw $#{amount}"
      super(@message)
    end
  end
end
