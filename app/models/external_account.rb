# 	# External account types
# 	EXTERNAL_ACCOUNT_PAYPAL = 1
# 	EXTERNAL_ACCOUNT_CREDITCARD = 2
# 	EXTERNAL_ACCOUNT_CHECK = 3
# 	EXTERNAL_ACCOUNT_BANK_TRANSFER = 4
# 	EXTERNAL_ACCOUNT_GOOGLE_CHECKOUT = 5
# 	EXTERNAL_ACCOUNT_2CHECKOUT = 6
#
# 	PAYPAL_VERIFIED_EMAIL_STATUS = 'verified'
class ExternalAccount < ApplicationRecord
  belongs_to :normal_user, foreign_key: :owner_id, class_name: 'User'

  has_many :payments, as: :source_account, class_name: 'MoneyTransaction'
  has_many :credits, as: :target_account, class_name: 'MoneyTransaction'
  has_many :account_lines, as: :account

  has_one :identity_verification, as: :verified_item, dependent: :destroy

  validates_uniqueness_of :identifier, scope: [:external_account_type], message: 'An identical account already exists'
  validate :external_account_paypal

  VERIFIED_USER_STATUS = 'verified'.freeze

  belongs_to :currency

  EXTERNAL_ACCOUNTS_LIST = [EXTERNAL_ACCOUNT_PAYPAL, EXTERNAL_ACCOUNT_CREDITCARD, EXTERNAL_ACCOUNT_CHECK].freeze
  EXTERNAL_ACCOUNT_FIELDS = { EXTERNAL_ACCOUNT_PAYPAL => [[:identifier, N_('Email address used in PayPal system')]] }.freeze

  NAME = { EXTERNAL_ACCOUNT_PAYPAL => N_('PayPal'),
           EXTERNAL_ACCOUNT_CREDITCARD => N_('credit card'),
           EXTERNAL_ACCOUNT_CHECK => N_('check by mail'),
           EXTERNAL_ACCOUNT_BANK_TRANSFER => N_('bank transfer'),
           EXTERNAL_ACCOUNT_GOOGLE_CHECKOUT => N_('Google Checkout'),
           EXTERNAL_ACCOUNT_2CHECKOUT => N_('2Checkout') }.freeze

  DESCRIPTION = { EXTERNAL_ACCOUNT_PAYPAL => N_('pay or get paid through PayPal'),
                  EXTERNAL_ACCOUNT_CREDITCARD => N_('pay via a credit card'),
                  EXTERNAL_ACCOUNT_CHECK => N_('get paid with a paper check'),
                  EXTERNAL_ACCOUNT_BANK_TRANSFER => N_('pay or get paid by doing a bank transfer'),
                  EXTERNAL_ACCOUNT_GOOGLE_CHECKOUT => N_('pay or get paid through Google Checkout') }.freeze

  def show_identifier
    if external_account_type == EXTERNAL_ACCOUNT_PAYPAL
      identifier
    else
      'TBD'
    end
  end

  def can_deposit?
    EXTERNAL_ACCOUNTS_THAT_CAN_DEPOSIT.include?(external_account_type)
  end

  def can_withdraw?
    EXTERNAL_ACCOUNTS_THAT_CAN_WITHDRAW.include?(external_account_type)
  end

  def has_balance?
    false
  end

  def update_user_verification
    if (external_account_type == EXTERNAL_ACCOUNT_PAYPAL) &&
       (status == PAYPAL_VERIFIED_EMAIL_STATUS) &&
       (identifier.casecmp(normal_user.email.downcase).zero? || (verified == 1)) &&
       fname.casecmp(normal_user.fname.downcase).zero? &&
       lname.casecmp(normal_user.lname.downcase).zero? &&
       !identity_verification
      if !normal_user.verified? && normal_user.can_receive_emails?
        ReminderMailer.profile_updated(normal_user, 'Your identity was successfully verified.').deliver_now
      end
      iv = IdentityVerification.new(chgtime: Time.now,
                                    status: VERIFICATION_OK)
      iv.normal_user = normal_user
      self.identity_verification = iv
    elsif !identity_verification && !normal_user.identity_verifications.where(status: VERIFICATION_OK).first
      if !normal_user.verified? && normal_user.can_receive_emails?
        ReminderMailer.external_account_validation(self, normal_user).deliver_now
      end
    end
  end

  def signature
    Digest::MD5.hexdigest(id.to_s + fname.to_s + lname.to_s + identifier + 'eehelzersomethinggreatexaccount')
  end

  private

  def external_account_paypal
    if external_account_type == EXTERNAL_ACCOUNT_PAYPAL
      unless identifier && identifier =~ /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i
        errors.add(:identifier, 'must be a valid email address')
      end
    end
  end

end
