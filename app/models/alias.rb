require 'securerandom'
class Alias < Client
  before_create :set_defaults
  def set_defaults
    self.userstatus = USER_STATUS_ALIAS
    self.fname = master_account.fname
    self.lname = 'Alias'
    self.password = SecureRandom.base64(10)
    set_next_nickname
  end

  # Generates methods:
  # def websites
  # def revisions
  # def text_resources
  # def web_messages
  # def projects
  # def bidding_projects
  %i(
    websites
    text_resources
    web_messages
    projects
    bidding_projects
  ).each do |resource_name|
    define_method resource_name.to_s do
      alias_profile.public_send(resource_name)
    end
  end

  delegate :bookmarks, to: :master_account

  delegate :money_accounts, to: :master_account

  delegate :money_account, to: :master_account

  delegate :bidding_projects, to: :alias_profile

  def can_create_projects?(website = nil)
    ((alias_profile.project_access_mode == AliasProfile::ALL_PROJECTS) && alias_profile.can_create_projects?) ||
      websites.include?(website)
  end

  def can_modify?(project)
    if project.is_a?(Project) && project.is_from_website?
      project = project.website
    end
    alias_profile.can_modify?(project)
  end

  def can_view?(project)
    if project.is_a?(Project) && project.is_from_website?
      project = project.website
    end
    alias_profile.can_view?(project)
  end

  def alias_of?(client)
    master_account == client
  end

  def can_deposit?
    alias_profile.financial_deposit
  end

  def can_pay?
    alias_profile.financial_pay
  end

  def can_view_finance?
    alias_profile.financial_view
  end

  def set_next_nickname
    count = 1
    alias_nick = "#{master_account.nickname}_alias#{count}"
    while User.find_by(nickname: alias_nick)
      count += 1
      alias_nick = "#{master_account.nickname}_alias#{count}"
    end
    self.nickname = alias_nick
  end

  def open_jobs(translator)
    jobs = master_account.open_jobs(translator)
    jobs.each do |_key, job_list|
      job_list.delete_if do |job|
        if job.class == RevisionLanguage
          not can_modify?(job.revision)
        elsif job.class == ResourceLanguage
          not can_modify?(job.text_resource)
        elsif job.class == WebsiteTranslationOffer
          not can_modify?(job.website)
        elsif job.class == ManagedWork
          job.owner.nil? || !can_modify?(job.owner_project)
        else
          raise "Invalid job class: #{job.class}"
        end
      end
    end
    jobs
  end

  def is_reviewer_of?(_x)
    false
  end

  def api_key
    self[:api_key] || master_account.api_key
  end
end
