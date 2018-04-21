#   operation_code: (a human text can be found on money_transactions_helper.rb)
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
#     TRANSFER_VOUCHER = 31
class MoneyTransaction < ApplicationRecord
  has_many :account_lines, dependent: :destroy
  belongs_to :source_account, polymorphic: true
  belongs_to :target_account, polymorphic: true
  belongs_to :owner, polymorphic: true
  belongs_to :currency

  # HACK: to be able to include in a query
  class SourceUserAccount < User; end
  class TargetUserAccount < User; end
  belongs_to :source_user_account, foreign_key: 'source_account_id'
  belongs_to :target_user_account, foreign_key: 'source_account_id'

  has_one :lock, as: :object, dependent: :destroy
  include Lockable

  belongs_to :affiliate_account, foreign_key: :affiliate_account_id, class_name: 'MoneyAccount'

  def description(user)
    if target_account.class == BidAccount
      project = target_account.bid.chat.revision.project.name
      language = target_account.bid.revision_language.language.nname
      return _('Translation of %s to %s') % [project, language]
    elsif target_account.class == ResourceLanguageAccount
      resource_language = target_account.resource_language
      return _('Translation of %s to %s') % [resource_language.text_resource.name, resource_language.language.nname]
    elsif target_account.class == UserAccount
      if target_account.normal_user.id == user.id
        return _('Deposit to your ICanLocalize account for translation work')
      else
        return _('Deposit to the ICanLocalize account of %s') % target_account.normal_user.full_name
      end
    elsif target_account.class == ExternalAccount
      if target_account.normal_user == user
        return _('Withdraw to your external %s account') % ExternalAccount::NAME[target_account.external_account_type]
      else
        return _('Withdraw to the %s account of %s') % [
          ExternalAccount::NAME[target_account.external_account_type],
          target_account.normal_user.full_name
        ]
      end
    elsif target_account.class == TaxAccount
      # NOTE: THIS IS NOT USED, WHEN SHOWING INVOICE WE HAVE A RETURN BEFORE
      # PRINTING A MONEY_TRANSACTION IF TARGET_ACOUNT CLASS IS TAXACCOUNT
      if owner.is_a? Invoice
        'VAT Tax in %s (%i%%)' % [Country.find(owner.tax_country_id).try(:name), owner.tax_rate] rescue 'VAT Tax'
      else
        # @ToDo use right country if owner is not an invoice
        'VAT Tax in %s (%i%%)' % [user.country.name, user.tax_rate]
      end
    elsif target_account.class == KeywordAccount
      project = target_account.keyword_project.owner.project.name
      language = target_account.keyword_project.owner.language.nname
      'Keyword Project from %s to %s' % [project, language]
    else
      'Other expenses'
    end
  rescue => e
    'Problem getting description.'
  end

  def print_amount
    "#{amount} #{currency.disp_name}"
  end

  def destroy
    # remove empty and without-history target bid accounts
    logger.info "------- Checking  money_transaction #{id}"
    if target_account.class == BidAccount
      bid = target_account.bid
      logger.info "Checking bid #{bid.id} - #{bid.status}"
      if bid.status == BID_WAITING_FOR_PAYMENT
        logger.info 'deleting this bid'
        bid.status = BID_GIVEN
        bid.save!
      end
    end
    super
  end

  def self.requested_payments
    where('(status = ?) AND (operation_code = ?)', TRANSFER_REQUESTED, TRANSFER_PAYMENT_TO_EXTERNAL_ACCOUNT)
  end

  def self.requested_payments_count
    requested_payments.count
  end

  def payment_from_client?
    [TRANSFER_DEPOSIT_TO_BID_ESCROW,
     TRANSFER_DEPOSIT_TO_RESOURCE_TRANSLATION,
     TRANSFER_DEPOSIT_TO_RESOURCE_TRANSLATION_WITH_REVIEW,
     TRANSFER_DEPOSIT_TO_RESOURCE_REVIEW,
     TRANSFER_DEPOSIT_TO_PROJECT_REVIEW,
     TRANSFER_DEPOSIT_FOR_SERVICE_WORK,
     TRANSFER_PAYMENT_FOR_INSTANT_TRANSLATION,
     TRANSFER_PAYMENT_FOR_TA_RENTAL].include? operation_code
  end

  def self.client_payment_codes
    [TRANSFER_DEPOSIT_TO_BID_ESCROW,
     TRANSFER_DEPOSIT_TO_RESOURCE_TRANSLATION,
     TRANSFER_DEPOSIT_TO_RESOURCE_TRANSLATION_WITH_REVIEW,
     TRANSFER_DEPOSIT_TO_RESOURCE_REVIEW,
     TRANSFER_DEPOSIT_TO_PROJECT_REVIEW,
     TRANSFER_DEPOSIT_FOR_SERVICE_WORK,
     TRANSFER_PAYMENT_FOR_INSTANT_TRANSLATION,
     TRANSFER_PAYMENT_FOR_TA_RENTAL]
  end

end
