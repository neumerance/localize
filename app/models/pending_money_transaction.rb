# This model is used to record transactions that are put money in "hold_sum" in
# client's MoneyAccount For now is implemented only for cms_requests. When a
# payment for a language_pair with auto_assignment is done, a pending
# transaction will be recorded for each cms_request paid and the money will be
# moved to hold_sum to prevent client spending money for something else when a
# translator is assigned and starts work (assign_to_me method), corresponding
# transaction will be found and deleted while money are moved from hold_sum to
# BidAccount this will use paranoid gem to prevent deletion
class PendingMoneyTransaction < ApplicationRecord
  acts_as_paranoid
  belongs_to :money_account
  has_one :normal_user, through: :money_account
  belongs_to :owner, polymorphic: true

  validates :money_account, :owner, presence: true
  # A valid CmsRequests may cost 0 if all of its contents are already in
  # translation memory or if a private translator is used. So 0 is a valid amount.
  validates :amount, numericality: { greater_than_or_equal_to: 0 }

  # Allow only one active (not deleted) but multiple deleted
  # PendingMoneyTransaction records per CmsRequest. See icldev-2799 for use cases.
  validates :owner_id, uniqueness: {
    scope: [:owner_type, :deleted_at],
    message: 'cannot have more than one active (not deleted) PendingMoneyTransaction'
  }

  before_destroy :prevent_invalid_destruction

  # use move_to_hold_sum from money account to move money to hold sum (add code from there to transaction)
  def self.reserve_money_for_cms_requests(cms_records)
    pending_transactions = cms_records.map do |cms|
      # cms_request.cms_target_language.money_account is the same as cms_request.client.money_account
      required_balance, _bid_amounts, _rental_amounts, _payments_to_translator = cms.calculate_required_balance

      # TODO: remove the following lines in a couple of months (it was added only to help debug icldev-2646)
      if required_balance == 0
        wto = cms.website_translation_offer
        accepted_wtcs = wto.accepted_website_translation_contracts
        Rails.logger.warn 'Creating PendingMoneyTransaction with amount=0. ' \
          "CmsRequest ID=#{cms.id}, " \
          "Translator autoassign=#{wto.automatic_translator_assignment}, " \
          "Accepted WTC count=#{accepted_wtcs.count}, " \
          "Total price per word=#{wto.total_price_per_word}" \
          "Private translator=#{wto.all_translators_are_private?}"
      end

      self.new(owner: cms, amount: required_balance, money_account: cms.website.client.money_account)
    end

    ActiveRecord::Base.transaction do
      pending_transactions.each do |pt|
        pt.save!
        pt.money_account.move_to_hold_sum(pt.amount)
      end
    end
  end

  def self.release_money_for_cms_request(cms_record)
    pt = self.where(owner: cms_record).take
    if pt
      ActiveRecord::Base.transaction do
        pt.money_account.release_hold_sum(pt.amount)
        pt.destroy!
      end
    end
  end

  private

  # PendingMoneyTransaction records should only be destroyed by the
  # `self.release_money_for_cms_request` method to ensure money is moved from
  # the hold_sum back into the client's account.
  def prevent_invalid_destruction
    # Returning false aborts destruction
    unless caller.join =~ /release_money_for_cms_request/
      raise 'This record should only be destroyed by calling ' \
            'PendingMoneyTransaction.release_money_for_cms_request'
    end
  end
end
