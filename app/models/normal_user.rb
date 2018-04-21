class NormalUser < User
  has_many :reminders
  # Users never have more than one money account. Keept for compatibility
  has_many :money_accounts, foreign_key: :owner_id, class_name: 'UserAccount'
  has_one :money_account, foreign_key: :owner_id, class_name: 'UserAccount'
  has_many :external_accounts, foreign_key: :owner_id, class_name: 'ExternalAccount'
  has_many :support_tickets

  has_many :claims_to_others, class_name: 'Arbitration', foreign_key: :initiator_id
  has_many :claims_by_others, class_name: 'Arbitration', foreign_key: :against_id

  has_one :resume, as: :owner
  has_one :bionote, as: :owner

  has_many :user_identity_documents, foreign_key: :owner_id, dependent: :destroy
  has_many :identity_verifications
  has_many :not_ok_identity_verifications, -> { where("(status != #{VERIFICATION_OK}) AND ((verified_item_type='UserDocument') OR (verified_item_type='ZippedFile'))") }, class_name: 'IdentityVerification', foreign_key: :normal_user_id
  has_many :pending_identity_verifications, -> { where("(status = #{VERIFICATION_PENDING}) AND ((verified_item_type='UserDocument') OR (verified_item_type='ZippedFile'))") }, class_name: 'IdentityVerification', foreign_key: :normal_user_id

  has_many :zipped_files, foreign_key: :by_user_id

  has_one :invitation

  belongs_to :affiliate, foreign_key: :affiliate_id, class_name: 'User'
  has_many :invitees, foreign_key: :affiliate_id, class_name: 'User'

  def arbitrations(extra_sql = '')
    Arbitration.find_by_sql("SELECT distinct arbitrations.* from arbitrations where ((initiator_id=#{id}) OR (against_id=#{id})) ORDER BY id DESC #{extra_sql};")
  end

  def open_arbitrations(extra_sql = '')
    Arbitration.find_by_sql("SELECT distinct arbitrations.* from arbitrations where ((initiator_id=#{id}) OR (against_id=#{id})) AND (status != #{ARBITRATION_CLOSED}) ORDER BY id DESC #{extra_sql};")
  end

  def todos(count_only = nil)
    todos = [] # list of things that need to be done
    active_items = 0

    u_active_items, u_todos = super(count_only)
    active_items += u_active_items
    todos += u_todos

    verification_status = verified? ? TODO_STATUS_DONE : !pending_identity_verifications.empty? ? TODO_STATUS_PENDING : TODO_STATUS_MISSING
    todos << [verification_status,
              _('Verify your identity'), _('In order to pay for projects or to withdraw money your identity must be verified.'), { controller: :users, action: :verification, id: id }, true]
    active_items += 1 if count_only ? (verification_status == count_only) : (verification_status != TODO_STATUS_DONE)

    [active_items, todos]
  end

  def verified?
    AUTOMATIC_TRANSLATOR_APPROVAL ? (!identity_verifications.where(["status=#{VERIFICATION_OK}"]).empty? || (Rails.env == 'sandbox')) : !identity_verifications.where(["status=#{VERIFICATION_OK}"]).empty?
  end

  def unverify
    identity_verifications.where(status: VERIFICATION_OK).find_each { |iv| iv.update_attributes(status: VERIFICATION_PENDING) }
  end

  def verification_status_text
    if verified?
      _('Identity verified')
    else
      _('Identity not verified')
    end
  end

  def get_money_account(currency_id = nil)
    money_account || create_default_money_account(currency_id)
  end

  def find_or_create_account(currency_id)
    # look for the translator account in that currency
    account = money_accounts.where(currency_id: currency_id).first
    # if this translator doesn't yet have an account in this currency, lets create it now
    unless account
      account = UserAccount.new(currency_id: currency_id)
      account.normal_user = self
      account.save!
    end
    account
  end

  def generate_nickname
    # nickname must be created before the new User record is validated. If fname
    # or lname are not present, the User model should generate a validation
    # error, but regardless this method should create a nickname, or else
    # an additional validation error will be generated due to the nickname
    # being blank (that's confusing for the user as we are not asking him to
    # enter a nickname, we're creating it automatically).
    base_nickname = if fname.present? && lname.present?
                      # Example brunoF
                      fname.downcase + lname[0].upcase
                    else
                      'user'
                    end

    suffix = 0
    nickname = base_nickname
    # try the nickname without a suffix first (e.g., brunoF)
    while User.where(nickname: nickname).first
      # if the base nickname is taken, add a suffix (e.g., brunoF-1)
      suffix += 1
      nickname = "#{base_nickname}-#{suffix}"
    end

    self.nickname = nickname
  end

  def generate_password
    # Create a 12 digit alphanumerical password
    self.password = SecureRandom.base64(9)
  end

  def has_to_pay_taxes?
    false
  end

  def is_allowed_to_withdraw?
    false
  end

  def create_default_money_account(currency_id = nil)
    # Use DEFAULT_CURRENCY_ID even if the method is explicitly passed nil as an
    # argument (default parameter values do not apply when nil is explicitly
    # passed)
    currency_id = DEFAULT_CURRENCY_ID	unless currency_id.present?
    create_money_account(currency_id: currency_id, balance: 0)
  end
end
