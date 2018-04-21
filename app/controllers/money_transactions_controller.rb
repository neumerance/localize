class MoneyTransactionsController < ApplicationController
  prepend_before_action :setup_user
  layout :determine_layout
  before_action :verify_admin
  before_action :setup_money_transaction, only: [:edit, :update]
  before_action :setup_help

  def index
    conditions_text = []
    conditions_values = []

    if params[:from_date].is_a? Array
      params[:from_date] = params[:from_date].try(:first)
    end

    if params[:to_date].is_a? Array
      params[:to_date] = params[:to_date].try(:first)
    end

    unless params[:from_date].blank?
      conditions_text << 'chgtime >= ?'
      conditions_values << params[:from_date].to_date
    end
    unless params[:to_date].blank?
      conditions_text << 'chgtime <= ?'
      conditions_values << params[:to_date].to_date
    end
    unless params[:from_amount].blank?
      conditions_text << 'amount >= ?'
      conditions_values << params[:from_amount].delete(',').to_f
    end
    unless params[:to_amount].blank?
      conditions_text << 'amount <= ?'
      conditions_values << params[:to_amount].delete(',').to_f
    end

    if !params[:user_id].blank?
      user = User.find(params[:user_id])
      if user.nil?
        flash[:notice] = 'User ID not found.'
      else
        money_account_id = user.money_accounts.first.try(:id)
        conditions_text << '(source_account_id = ? or target_account_id = ?)'
        conditions_values += Array.new(2) { money_account_id }
      end
    elsif !params[:user_nickname].blank?
      user = User.find_by(nickname: params[:user_nickname])
      if user.nil?
        flash[:notice] = 'Nickname not found.'
      else
        money_account_id = user.money_accounts.first.try(:id)
        conditions_text << '(source_account_id = ? or target_account_id = ?)'
        conditions_values += Array.new(2) { money_account_id }
      end
    end

    params[:per_page] ||= 20
    @per_page = params[:per_page].blank? ? 20 : params[:per_page].to_i
    where = [conditions_text.join(' and ')] + conditions_values
    money_transactions = where.first.blank? ? MoneyTransaction.all.order('money_transactions.chgtime DESC').page(params[:page]).per(params[:per_page]) : MoneyTransaction.where(where).order('money_transactions.chgtime DESC').page(params[:page]).per(params[:per_page])
    money_transactions.each do |trans|
      source = trans.source_account
      target = trans.target_account
      trans.source_account = target if trans.source_account.is_a? UserAccount
      trans.target_account = source if trans.target_account.is_a? BidAccount
    end
    @money_transactions = money_transactions
  end

  def edit
    @refer = request.referer
    @external_account_types = ExternalAccount::NAME.keys.sort.collect do |k|
      [ExternalAccount::NAME[k].capitalize, k]
    end
  end

  def update
    @money_transaction.update_attributes!(params[:money_transaction])
    @money_transaction.owner.update_attributes!(params[:invoice])
    flash[:notice] = 'Transaction updated!'
    back_url = Rails.application.routes.recognize_path(params[:refer])
    redirect_to back_url
  end

  private

  def setup_money_transaction
    @money_transaction = MoneyTransaction.find(params[:id])
  end

  def verify_admin
    unless @user.has_admin_privileges?
      set_err('You are not authorized to view this')
      false
    end
  end
end
