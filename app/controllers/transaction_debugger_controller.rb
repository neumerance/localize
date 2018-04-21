class TransactionDebuggerController < ApplicationController
  include ::RootAccountCreate

  before_action :verify_sandbox

  def clear_account_lines
    MoneyTransaction.delete_all
    AccountLine.delete_all
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def set_balance
    @account = MoneyAccount.find(params[:account_id].to_i)
    @balance = params[:balance].to_f
    @account.update_attributes(balance: @balance)

    respond_to do |format|
      format.html
      format.xml
    end
  end

  def set_root_balance
    @currency_id = params[:currency_id].to_i
    @balance = params[:balance].to_f

    @account = find_or_create_root_account(@currency_id)

    @account.update_attributes(balance: @balance)

    respond_to do |format|
      format.html
      format.xml
    end
  end

  def get_balance
    @account = MoneyAccount.find(params[:account_id].to_i)
    @balance = @account.balance

    respond_to do |format|
      format.html
      format.xml
    end
  end

  def get_root_balance
    @currency_id = params[:currency_id].to_i
    @account = find_or_create_root_account(@currency_id)
    @balance = @account.balance

    respond_to do |format|
      format.html
      format.xml
    end
  end

  def test_transfer_money

    @currency_id = params[:currency_id].to_i

    @from_account = MoneyAccount.find(params[:from_account_id].to_i)
    @to_account = MoneyAccount.find(params[:to_account_id].to_i)
    @root_account = find_or_create_root_account(@currency_id)

    @before_from_balance = @from_account.balance
    @before_to_balance = @to_account.balance
    @before_root_balance = @root_account.balance

    @amount = params[:amount].to_f
    @operation_code = params[:operation_code].to_i
    @fee_rate = params[:fee_rate].to_f

    @serial = params[:serial]

    MoneyTransactionProcessor.transfer_money(@from_account, @to_account, @amount, @currency_id, @operation_code, @fee_rate)
    @from_account.reload
    @to_account.reload
    @root_account.reload

    @ok = (@before_from_balance + @before_to_balance + @before_root_balance) == (@from_account.balance + @to_account.balance + @root_account.balance)

    logger.info " ---------- #{@serial} - STATUS: #{@ok} ------------ "

    respond_to do |format|
      format.html
      format.xml
    end
  end

  def check_history_integrity
    @inconsistencies = 0
    MoneyTransaction.includes(:account_lines).each do |mt|
      mt.account_lines.each do |al|
        unless al.account.is_a?(RootAccount) || [mt.source_account_id, mt.target_account_id].include?(al.account_id)
          logger.info "#{mt.source_account_id} to #{mt.target_account_id} bounded to #{al.account_id}"
          @inconsistencies += 1
        end
      end
    end

    respond_to do |format|
      format.xml
    end
  end

  def check_account_integrity
    account = MoneyAccount.find(params[:account_id].to_i)
    initial_balance = params[:initial_balance].to_f

    @zero_addition = false
    @balance_mismatch = false

    final_balace = if account.account_lines.count == 0
                     initial_balance
                   else
                     account.account_lines[-1].balance
                   end
    @ending_balance_ok = same_amount(final_balace, account.balance)
    unless @ending_balance_ok
      logger.info "-------- PROBLEM (account #{account.id}): Final balance mismatch. Expecting #{final_balace}, got #{account.balance}"
    end

    prev_balance = initial_balance
    for account_line in account.account_lines
      addition = if account_line.money_transaction.source_account == account
                   -account_line.money_transaction.amount
                 elsif account.class == RootAccount
                   account_line.money_transaction.fee
                 else
                   account_line.money_transaction.amount - account_line.money_transaction.fee
                 end

      if addition == 0
        @zero_addition = true
        logger.info "-------- PROBLEM (account #{account.id}): Zero addition in account line #{account_line.id}"
      end

      unless same_amount(prev_balance + addition, account_line.balance)
        @balance_mismatch = true
        logger.info "-------- PROBLEM (account #{account.id}): prev_balance: #{prev_balance}, addition: #{addition} = #{prev_balance + addition} /// account_line.balance: #{account_line.balance}"
      end
      prev_balance += addition
    end

    respond_to do |format|
      format.html
      format.xml
    end
  end

  private

  def same_amount(v1, v2)
    (v1 - v2).abs <= 0.01
  end

  def verify_sandbox
    Rails.env == 'sandbox'
  end

end
