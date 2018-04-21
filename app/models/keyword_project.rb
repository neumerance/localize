#   status:
#     PENDING_PAYMENT = 0
#     PAID = 1
#     PENDING_CLIENT_APPROVAL = 2
class KeywordProject < ApplicationRecord
  # A keyword project belongs to one language from a project.
  # Possible models: ResourceLanguage, RevisionLanguage and WebsiteTranslationOffer
  belongs_to :owner, polymorphic: true
  validates_presence_of :owner_type, :owner_id

  has_many :purchased_keyword_packages
  has_one :keyword_package, through: :purchased_keyword_packages
  has_many :keywords, through: :purchased_keyword_packages
  has_one :account, foreign_key: :owner_id, class_name: 'KeywordAccount', dependent: :destroy

  # status
  PENDING_PAYMENT = 0
  PAID = 1
  PENDING_CLIENT_APPROVAL = 2

  def client
    case owner
    when ResourceLanguage then owner.text_resource.client
    when RevisionLanguage then owner.revision.client
    when WebsiteTranslationOffer then owner.website.client
    else raise "No known owner for this proejct: #{owner}"
    end
  end

  def pay!
    update_attribute :status, PAID
    if owner.translator && owner.translator.can_receive_emails?
      ReminderMailer.new_keyword_project(owner.translator, self).deliver_now
    end
  end

  def paid?
    [PAID, PENDING_CLIENT_APPROVAL].include? status
  end

  def pending_client_approval!
    update_attribute :status, PENDING_CLIENT_APPROVAL
  end

  def pending_approval?
    status == PENDING_CLIENT_APPROVAL
  end

  def complete!
    transaction do
      keywords.each { |kw| kw.update_attribute :status, Keyword::TRANSLATED }

      if owner.project.keyword_projects.all?(&:completed?)
        if owner.project.client.can_receive_emails?
          ReminderMailer.keyword_project_completed(owner.project).deliver_now
        end
      end

      if owner.is_a? RevisionLanguage
        pending_client_approval!
      else
        pay_translator
      end
    end
  end

  def pay_translator
    from = account
    to = owner.translator.find_or_create_account(DEFAULT_CURRENCY_ID)
    amount = translator_payment
    MoneyTransactionProcessor.transfer_money(from, to, amount, DEFAULT_CURRENCY_ID, TRANSFER_PAYMENT_FROM_KEYWORD_LOCALIZATION, FEE_RATE, owner.project.client.affiliate)
  end

  def translator_payment
    if keyword_package.reuse_package?
      account.balance
    else
      translator_payment_for(keywords.count)
    end
  end

  def translator_payment_for(num_words)
    (num_words.to_f / keyword_package.keywords_number) * keyword_package.price
  end

  def completed?
    keywords.find_by(status: 0).nil?
  end

  def self.create_free_samples(project, languages, keywords_count)
    package = KeywordPackage.reuse_package

    keyword_projects = create_keyword_projects(project, languages, package, true)
    purchased_keyword_packages = create_purchased_keyword_packages(keyword_projects, 0, package, keywords_count)
  end

  def find_or_create_account
    return account if account
    raise 'need to be persisted to create an account to it' if new_record?
    KeywordAccount.create!(currency_id: 1, owner_id: id, balance: 0)
  end

  def self.create_new_packages(project, languages, keyword_package, keywords_texts)
    ActiveRecord::Base.transaction do
      keyword_projects = create_keyword_projects(project, languages, keyword_package)
      purchased_keyword_packages = create_purchased_keyword_packages(keyword_projects, keywords_texts.size, keyword_package)
      create_keywords(purchased_keyword_packages, keywords_texts)

      if keyword_package.reuse_package?
        languages.each do |lang|
          proj_lang = project.project_languages.to_a.find { |pl| pl.language_id == lang.id }
          projects_and_amounts = proj_lang.subtract_remaining_keywords(keywords_texts.size)
          projects_and_amounts.each do |proj, amount|
            kwp = keyword_projects.find { |k| k.owner == proj_lang }
            from = proj.account
            to = kwp.find_or_create_account
            amount = amount
            if amount > 0
              MoneyTransactionProcessor.transfer_money(from, to, amount, DEFAULT_CURRENCY_ID, TRANSFER_REUSE_KEYWORD, FEE_RATE, project.client.affiliate)
            end
            if proj_lang.translator && proj_lang.translator.can_receive_emails?
              ReminderMailer.new_keyword_project(proj_lang.translator, kwp).deliver_now
            end
          end
        end
      end

      # Pay for website keywords automatically when user is from website
      if project.is_a? Website
        client_account = project.client.money_account
        keyword_projects.each do |kp|
          next if kp.keyword_package.reuse_package?
          client_account.reload
          next unless client_account.balance > kp.keyword_package.price
          from = client_account
          to = kp.find_or_create_account
          amount = kp.keyword_package.price
          op_code = TRANSFER_PAYMENT_FROM_KEYWORD_LOCALIZATION
          MoneyTransactionProcessor.transfer_money(from, to, amount, DEFAULT_CURRENCY_ID, op_code)
          kp.pay!
        end
      end
    end
  end

  def transfer_escrow
    from = owner.project.client.money_account
    to = find_or_create_account
    MoneyTransactionProcessor.transfer_money(from, to, keyword_package.price, DEFAULT_CURRENCY_ID, TRANSFER_PAYMENT_FROM_KEYWORD_LOCALIZATION)
  end

  def pending?
    purchased_keyword_packages.find_all { |pkp| pkp.keywords.find_by(status: 0).nil? }.empty?
  end

  private_class_method

  def self.create_keyword_projects(project, languages, keyword_package, free_sample = false)
    status = if keyword_package.reuse_package?
               KeywordProject::PAID
             else
               KeywordProject::PENDING_PAYMENT
             end

    KeywordProject.create(
      languages.map do |language|
        project_language = project.project_languages.find_all { |l| l.language_id == language.id }.first
        {
          owner_id: project_language.id,
          owner_type: project_language.class.to_s,
          status: status,
          free_sample: free_sample
        }
      end
    )
  end

  def self.create_purchased_keyword_packages(keyword_projects, number_keywords, keyword_package, remaining_keywords = false)
    # remaining_keywords is pre-set when giving away free samples
    unless remaining_keywords
      remaining_keywords = if keyword_package.reuse_package?
                             0
                           else
                             keyword_package.keywords_number - number_keywords
                           end
    end

    PurchasedKeywordPackage.create(
      keyword_projects.map do |keyword_project|
        {
          keyword_project_id: keyword_project.id,
          keyword_package_id: keyword_package.id,
          remaining_keywords: remaining_keywords,
          price: keyword_package.price
        }
      end
    )
  end

  def self.create_keywords(purchased_keyword_packages, keywords_texts)
    Keyword.create(
      keywords_texts.product(purchased_keyword_packages).map do |text, pkp|
        {
          purchased_keyword_package_id: pkp.id,
          text: text,
          status: Keyword::PENDING_TRANSLATION
        }
      end.flatten
    )
  end

end
