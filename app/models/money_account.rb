class MoneyAccount < ApplicationRecord
  has_many :payments, as: :source_account, class_name: 'MoneyTransaction'
  has_many :credits, as: :target_account, class_name: 'MoneyTransaction'
  has_many :account_lines, as: :account
  has_many :money_transactions, through: :account_lines

  belongs_to :currency
  belongs_to :normal_user, foreign_key: :owner_id, class_name: 'User'
  has_one :lock, as: :object, dependent: :destroy

  has_many :cms_target_languages
  has_many :web_messages

  def has_balance?
    true
  end

  def move_to_hold_sum(amount)
    self.reload
    raise "Not enough balance in MoneyAccount #{id} ($#{self.balance}) to move $#{amount} to hold_sum." if self.balance < amount
    Rails.logger.info "------- MoneyAccount ##{id}: Moving to hold #{amount}. Previous hold sum amount: #{self.hold_sum} "
    self.balance -= amount
    self.hold_sum += amount
    save!
  end

  def release_hold_sum(amount)
    self.reload
    raise "Not enough funds in MoneyAccount #{id} hold_sum ($#{self.hold_sum}) to release $#{amount} to balance." if self.hold_sum < amount
    Rails.logger.info "------- MoneyAccount ##{id}: Moving from hold #{amount}. Previous hold sum amount: #{self.hold_sum} "
    self.balance += amount
    self.hold_sum -= amount
    save!
  end

  def has_enough_money_for(params)
    if params[:text_resource] && params[:resource_chats]
      has_enough_money_for_resources_chat(params[:text_resource], params[:resource_chats])
    else
      raise "Can't decide if has_enough_money_for this parameters: #{params.inspect}"
    end
  end

  def has_enough_money_for_resources_chat(_text_resource, resource_chats)
    amount = 0
    resource_chats.each do |resource_chat|
      amount += resource_chat.resource_language.cost
    end
    (self.balance + 0.01) >= amount
  end

  def pending_total_expenses
    res = 0
    pending_web_messages = 0

    preload_associations = :language, { cms_request: [:translator, :website] }

    expiration_begin_date = Time.current - CMS_TARGET_LANGUAGE_EXPIRATION_MONTHS.months

    pending_cms_target_languages = cms_target_languages.
                                   includes(*preload_associations).
                                   where(status: CMS_TARGET_LANGUAGE_CREATED).
                                   where('created_at > ?', expiration_begin_date)

    # TODO: Refactor (see icldev-2509).
    pending_cms_target_languages.each do |cms_target_language|
      # Memoize frequently used values
      cms_request = cms_target_language.cms_request
      # There is no point in trying to memoize the contract and pass it to
      # CmsRequest#calculate_required_balance, as it is a different one at each
      # iteration of the loop.

      required_balance, bid_amounts, rental_amounts, payments_to_translator =
        cms_request.calculate_required_balance([cms_target_language], nil)
      res += required_balance
    end

    # for assigned jobs, cms_requests are already paid in hold_sum, but also calculated inside pending_expenses
    # this line removes the duplication
    if self.respond_to?(:user)
      res -= user.pending_amount if user.is_a?(Client)

      if user.is_a?(Client) # Client has methods [web_messages_pending_translation, web_messages_pending_review]
        user.web_messages_pending_translation.each { |m| res += m.translation_price }
        user.web_messages_pending_review.each { |m| res += m.review_price }
        pending_web_messages = user.web_messages_pending_translation + user.web_messages_pending_review
      end
    end

    [BigDecimal(res.round(2).to_s), pending_cms_target_languages, pending_web_messages]
  end

  def data_for_graph
    data = { date: [], balance: [], calc_balance: [] }
    calc_balance = 0
    MoneyTransaction.where(['source_account_id = ? or target_account_id = ?', id, id]).limit(1000).each do |mt|
      data[:date] << mt.chgtime.to_date
      if mt.source_account_id == id
        calc_balance -= mt.amount.to_f
      else
        calc_balance += mt.amount.to_f
      end
      data[:calc_balance] << calc_balance.to_f
    end
    data
  end

  # This is created to fix issue on RootAccount when it reached
  # 999999.99
  def recalculate_balance_since(id)
    balance = account_lines.find(id).balance
    account_lines = self.account_lines.where(['id > ?', id])

    account_lines.each do |account_line|
      raise 'Not Valid Money Account' unless account_line.account_id == self.id

      addition = if account_line.money_transaction.source_account == self
                   -account_line.money_transaction.amount
                 elsif self.class == RootAccount
                   account_line.money_transaction.fee
                 else
                   account_line.money_transaction.amount - account_line.money_transaction.fee
                 end

      balance += addition
      account_line.update_attribute :balance, balance
    end

    update_attribute :balance, balance
  end

  def total_balance
    balance + hold_sum
  end

  def adjusted_expenses
    expenses = self.pending_total_expenses[0]
    if self.respond_to?(:user) && self.normal_user.is_a?(Client)
      expenses += self.normal_user.pending_amount
    end
    expenses
  end

  def available_balance
    total_balance - adjusted_expenses.abs
  end

  class << self
    def manual_transfer(source_account, target_account, amount, description)
      # @ToDo
      #   - withdraw money
      #   - deposit money
    end

    def get_for(resource, id)
      account = case resource
                when :user
                  User.find(id).money_accounts.first
                when :resource_chat # Software project: text_resource
                  ResourceChat.find(id).resource_language.money_accounts.first
                when :chat # bid project
                  Chat.find(id).bids.first.account
                end
    end

    def url_for(resource, id)
      account = get_for resource, id
      "https://www.icanlocalize.com/finance/account_history/#{account.id}"
    end
  end
end
