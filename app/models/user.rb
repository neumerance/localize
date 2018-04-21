# 	verification_level: this is aparently not used
# 	status:
# 		USER_STATUS_NEW = 0
# 		USER_STATUS_REGISTERED = 1
# 		USER_STATUS_QUALIFIED = 2
# 		USER_STATUS_CLOSED = 3
# 		USER_STATUS_PRIVATE_TRANSLATOR = 4
# 		USER_STATUS_ALIAS = 5
class User < ApplicationRecord

  require 'csv'

  has_many :user_sessions
  has_many :messages
  has_many :versions, foreign_key: :by_user_id
  has_many :bookmarks
  has_many :markings, -> { joins(:user).where('userstatus != 3') }, class_name: 'Bookmark', as: :resource
  has_many :arbitration_offers
  has_many :invoices
  has_many :pending_invoices, -> { where('status IN (?)', [TXN_CREATED, TXN_PENDING]) }, class_name: 'Invoice', foreign_key: :user_id
  has_many :completed_invoices, -> { where('status IN (?)', [TXN_COMPLETED]) }, class_name: 'Invoice', foreign_key: :user_id
  has_many :user_downloads, dependent: :destroy
  has_many :downloads, through: :user_downloads
  has_many :user_clicks
  has_many :vacations, dependent: :destroy
  has_many :sent_notifications
  has_many :message_deliveries, dependent: :destroy
  has_many :aliases, class_name: 'User', foreign_key: :master_account
  belongs_to :master_account, class_name: 'User'

  has_many :created_issues, class_name: 'Issue', foreign_key: :initiator_id, dependent: :destroy
  has_many :targeted_issues, class_name: 'Issue', foreign_key: :target_id, dependent: :destroy

  belongs_to :country
  has_one :image, as: :owner, dependent: :destroy

  has_many :phones_users
  has_many :cats_users
  has_many :phones, through: :phones_users
  has_many :cats, through: :cats_users
  has_one :alias_profile

  attr_accessor :password

  validates :nickname, presence: true, uniqueness: true
  validates :fname, presence: true
  validates :lname, presence: true
  validates :password, presence: true, on: :create
  validates :email, presence: true, uniqueness: true
  validates :userstatus, inclusion: { in: (0..5).to_a }, allow_nil: true
  # validate :client_userstatus - removing this because we already have records in DB that will not pass this

  validates_format_of :email, with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i

  before_save :create_password, if: Proc.new { password.present? }
  before_create :downcase_email

  USER_STATUS_TEXT = { USER_STATUS_NEW => N_('Signed up'),
                       USER_STATUS_REGISTERED => N_('Verified email'),
                       USER_STATUS_QUALIFIED => N_('Qualified translator'),
                       USER_STATUS_CLOSED => N_('Account closed') }.freeze

  USER_LEVEL_TEXT = { NEW_TRANSLATOR => N_('New translator'),
                      NORMAL_TRANSLATOR => N_('Experienced translator'),
                      EXPERT_TRANSLATOR => N_('Expert translator') }.freeze

  NOTIFICATION_TEXT = {
    NEWSLETTER_NOTIFICATION => [N_('Newsletter'), N_('Tips and ideas to help you get more projects and improve productivity'), N_('Low bandwidth')],
    DAILY_RELEVANT_PROJECTS_NOTIFICATION => [N_('Daily digest for your profile'), N_('Complete list of new projects matching your profile'), N_('Daily')],
    DAILY_ALL_PROJECTS_NOTIFICATION => [N_('Daily projects roundup'), N_('Complete digest of all new projects'), N_('Daily')],
    MONTHLY_STATEMENT_NOTIFICATION => [N_('Financial statement'), N_('Your financial statement, showing your payments and withdrawals'), N_('Monthly')]
  }.freeze

  def reverse_tm?
    !!reverse_tm
  end

  def full_name(currentuser = nil)
    return 'You' if currentuser && (currentuser.id == id)

    res = ''
    res = if !nickname.blank?
            nickname
          else
            fname + ' ' + lname
          end
    res += "-#{type}" if currentuser && currentuser.has_supporter_privileges?
    res
  end

  def can_receive_emails?
    return true if userstatus != USER_STATUS_CLOSED && (self.is_a?(Supporter) || self.is_a?(Admin))
    (userstatus != USER_STATUS_CLOSED) &&
      (not bounced) &&
      (not email.to_s =~ /^unreg.*icanlocalize\.com/)
  end

  def full_real_name
    if !fname.blank? && !lname.blank?
      fname + ' ' + lname
    elsif !fname.blank?
      fname
    elsif !lname.blank?
      lname
    else
      'User'
    end
  end

  def email_with_name
    "#{fname} #{lname} <#{email}>"
  end

  def signature
    BCrypt::Password.create(PASSWORD_HASH_SECRET)
  end

  def todos(_count_only = nil)
    todos = [] # list of things that need to be done
    active_items = 0

    [active_items, todos]
  end

  # TODO: Replace the following bitmasks for something easier to understand
  def has_client_privileges?
    (USER_PRIVILEGES[self.class.to_s] & CLIENT_PRIVILEGES) != 0
  end

  def has_translator_privileges?
    (USER_PRIVILEGES[self.class.to_s] & TRANSLATOR_PRIVILEGES) != 0
  end

  def has_supporter_privileges?
    (USER_PRIVILEGES[self.class.to_s] & SUPPORTER_PRIVILEGES) != 0
  end

  def has_admin_privileges?
    (USER_PRIVILEGES[self.class.to_s] & ADMIN_PRIVILEGES) != 0
  end

  def logged_in?
    @logged_in_cache = UserSession.logged_in(id) if @logged_in_cache.nil?
    @logged_in_cache
  end

  def password_reset_signature(hash)
    BCrypt::Password.new(hash)
  rescue
    false
  end

  def is_bookmarked?(user)
    if @is_bookmarked.nil?
      @is_bookmarked = !markings.where(user_id: user.id).empty?
    end
    @is_bookmarked
  end

  def affiliate_key
    Digest::MD5.hexdigest(id.to_s + 'affiliatecoded87d9fa')
  end

  def vacations_by_date
    vacations.order('vacations.ending ASC')
  end

  def on_vacation?
    curtime = Time.now
    !vacations.where(['(beginning < ?) AND (ending > ?)', curtime, curtime]).empty?
  end

  def current_vacation
    curtime = Time.now
    vacations.where(['(beginning < ?) AND (ending > ?)', curtime, curtime]).first
  end

  def websites_for_translation_analytics
    websites.find_all { |x| x.translation_analytics_language_pairs.any? }
  end

  def notify_new_message(chat, message)
    if can_receive_emails?
      ReminderMailer.new_message_for_resource_translation(self, chat, message).deliver_now
    end

    message_delivery = MessageDelivery.new
    message_delivery.user = self
    message_delivery.message = message
    message_delivery.save

    if %w(Client Translator).include?(self[:type])
      create_reminder(EVENT_NEW_RESOURCE_TRANSLATION_MESSAGE, chat)
    end
  end

  def self.create_new(fname, lname, email)
    nickname_base = fname + lname
    idx = 1
    cont = true
    while cont
      nickname = "#{nickname_base}#{idx}"
      if User.where(nickname: nickname).first
        idx += 1
      else
        cont = false
      end
    end

    curtime = Time.now

    user = Client.create!(email: email,
                          fname: fname,
                          lname: lname,
                          userstatus: USER_STATUS_REGISTERED,
                          password: Digest::MD5.hexdigest((curtime + User.count).to_s)[0..6],
                          nickname: nickname,
                          notifications: NEWSLETTER_NOTIFICATION,
                          signup_date: curtime)

    user
  end

  def is_client?
    # self.instance_of? Client
    # ToDo This method was overwritten, it was returning true if is an alias also
    is_a? Client
  end

  def is_alias?
    is_a? Alias
  end

  def is_translator?
    type == 'Translator'
  end

  def create_reminder(event, object)
    reminder = Reminder.where(['(owner_id=?) AND (owner_type=?) AND (normal_user_id=?) AND (event=?)', object.class.to_s, object.id, id, event]).first
    unless reminder
      website_id = nil
      if object.class == WebsiteTranslationContract
        website_id = object.website_translation_offer.website_id
      elsif (object.class == Chat) && object.revision.cms_request
        website_id = object.revision.cms_request.website_id
      end

      reminder = Reminder.new(event: event, website_id: website_id)
      reminder.normal_user = self
      reminder.owner = object
      reminder.save!
    end
  end

  def delete_reminder(object)
    Reminder.where('(owner_type=?) AND (owner_id=?) AND (normal_user_id= ?)', object.class.to_s, object.id, id).destroy_all
  end

  # Alias overwrite this methods
  def alias?
    master_account
  end

  def alias_of?(_client)
    false
  end

  def aliases
    if alias?
      nil
    else
      User.where(master_account_id: id).where.not(userstatus: USER_STATUS_CLOSED)
    end
  end

  def can_modify?(project)
    project = project.project if project.is_a? Revision
    if project.is_a? Project
      projects.include?(project)
    elsif project.is_a? Website
      websites.include?(project)
    elsif project.is_a? WebMessage
      web_messages.include?(project)
    elsif project.is_a? WebsiteTranslationContract
      websites.include?(project.website)
    elsif project.is_a? TextResource
      text_resources.include?(project)
    elsif project.is_a? CmsRequest
      cms_requests.include?(project)
    elsif project.is_a? XliffTransUnitMrk
      project.client == self
    else
      raise "Unknown project class #{project.class}"
    end
  end

  def can_view?(project)
    if project.is_a? Project
      projects.include?(project)
    elsif project.is_a? Website
      websites.include?(project)
    elsif project.is_a? WebMessage
      web_messages.include?(project) || websites.include?(project.owner)
    elsif project.is_a? TextResource
      text_resources.include?(project)
    elsif project.is_a? WebsiteTranslationContract
      websites.include?(project.website)
    else
      raise "Unknown project class: #{project.class}"
    end
  end

  def can_create_projects?(_website = nil)
    false
  end

  def is_reviewer_of?(_x)
    false
  end

  def login_info
    { email => password }
  end

  def get_password
    BCrypt::Password.new(hash_password)
  end

  def get_userstatus_options
    options = USER_STATUS_TEXT.dup
    options.delete(2) if type == 'Client'
    options.invert.to_a
  end

  def authenticate(pwd)
    self.get_password == pwd
  end

  class << self
    def locate(locator)
      if locator.is_a?(String) || locator.is_a?(Symbol)
        locator.include?('@') ? find_by(email: locator) : find_by(nickname: locator)
      elsif locator.is_a? Integer
        find locator
      end
    end
    alias [] locate

    def login_info(locator)
      u = locate locator
      u.login_info
    end

    def system_user_ids
      User.where(email: SYSTEM_CLIENT_EMAILS).pluck(:id)
    end

  end

  # TODO: all methods from here to the end are to be used only for migrating to encrypted passwords,
  # remove them on the next realease after passwords were migrated
  def self.backup_and_delete_clear_text_password
    if password_column_exists
      encrypt_users_password
      backup_users_password
    end
  end

  # need to execute using sql to avoid attr_accessor :password and get the actual value from password column
  def self.password_column_exists
    !ActiveRecord::Base.connection.execute("SHOW COLUMNS FROM `users` LIKE 'password'").to_a.blank?
  end

  def self.encrypt_users_password
    @log = Logger.new('log/password_migration.log')
    @start_time = Time.now
    puts 'Migrating from file'
    encrypt_passwords_from_file(@log, @start_time)
    puts 'Finished file migration'
    puts 'Checking unmigrated accounts'
    remaining_users = ActiveRecord::Base.connection.execute('SELECT id, password FROM users WHERE hash_password IS NULL').to_a.to_h
    if remaining_users.size > 0
      puts "Migrating #{remaining_users.size} other users"
      remaining_users.each do |id, password|
        begin
          @log.info "Migrating ID: #{id} and email: #{password}"
          user = User.find(id)
          user.update_attribute(:hash_password, BCrypt::Password.create(password))
        rescue Exception => e
          m =  "RESCUED - #{e.message}; Er: #{e.inspect}; ID: #{id}"
          puts m
          @log.error m
        end
      end
    end
    puts "Migration of user passwords ended after #{Time.now - @start_time}"
  end

  def self.backup_users_password
    users = ActiveRecord::Base.connection.execute('SELECT id, password FROM users').to_a
    puts 'Backing up password.'
    CSV.open(Rails.root.join('..', "#{Time.now.to_i}_icl_user_password_backup.csv"), 'wb') do |csv|
      csv << %w(id password)
      users.each do |user|
        puts "Backing up: #{user[0]}"
        csv << user
      end
    end
  end

  def self.encrypt_passwords_from_file(log, start_time)
    count = 0
    csv = CSV.read(Rails.root.join('encrypted_passwords.csv'), 'rb')
    csv.each_slice(1000) do |slice|
      count += 1000
      slice.each do |line|
        begin
          User.transaction do
            user = User.find(line[0])
            if user.email == line[1] && user.hash_password != line[2]
              log.info "Migrating ID: #{line[0]} and email: #{line[1]}"
              user.update_attribute(:hash_password, line[2])
            else
              log.error "ERROR - no ID MATCH for id: #{user.id}. #{line[1]} is NOT #{user.email}"
            end
          end
        rescue Exception => e
          m =  "RESCUED - #{e.message}; Er: #{e.inspect}; ID: #{line[0]}"
          puts m
          log.error m
        end
      end
      puts "#{count} finished after #{Time.now - start_time}"
    end
  end

  def self.encrypt_passwords_to_file
    all_users = ActiveRecord::Base.connection.execute('SELECT id, email, password FROM users').to_a
    all = User.all.size
    i = 0
    t = Time.now
    CSV.open(Rails.root.join('..', "#{Time.now.to_i}_icl_user__encrypted_password.csv"), 'wb') do |csv|
      all_users.each do |user|
        i += 1
        csv << [user[0], user[1], BCrypt::Password.create(user[2])]
        puts "#{i} from #{all} after #{Time.now - t}"
      end
    end
  end

  def create_password
    self.hash_password = BCrypt::Password.create(password)
  end

  def downcase_email
    self.email = self.email.downcase
  end

  def client_userstatus
    unless userstatus.blank?
      errors.add(:userstatus, 'invalid user status for client') if type == 'Client' && (userstatus == 2 || userstatus > 3)
    end
  end

  def beta?
    self.beta_user
  end

end
