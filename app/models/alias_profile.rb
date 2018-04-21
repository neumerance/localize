class AliasProfile < ApplicationRecord
  belongs_to :user
  serialize :project_list
  serialize :website_list
  serialize :web_message_list
  serialize :text_resource_list

  ALL_PROJECTS = 0
  PROJECTS_LIST = 1

  before_create :set_defaults
  def set_defaults
    self.project_list = []
    self.website_list = []
    self.web_message_list = []
    self.text_resource_list = []
  end

  def all_projects_list
    project_list + website_list + web_message_list + text_resource_list
  end

  def update_projects(params)
    params[:projects] ||= []
    params[:websites] ||= []
    params[:text_resources] ||= []
    params[:web_messages] ||= []

    self.project_list = params[:projects]
    self.website_list = params[:websites]
    self.text_resource_list = params[:text_resources]
    self.web_message_list = params[:web_messages]
    save
  end

  def can_create_projects?
    (project_access_mode == ALL_PROJECTS) && project_create
  end

  def can_modify?(project)
    project = project.project if project.is_a? Revision
    case project_access_mode
    when ALL_PROJECTS then project_modify
    when PROJECTS_LIST then know_project?(project)
    else raise 'Invalid project access mode'
    end
  end

  def can_view?(project)
    case project_access_mode
    when ALL_PROJECTS then (project_view || project_modify)
    when PROJECTS_LIST then know_project?(project)
    else raise 'Invalid project access mode'
    end
  end

  def revisions
    case project_access_mode
    when ALL_PROJECTS then
      user.master_account.revisions
    when PROJECTS_LIST then
      Revision.where('revisions.project_id in (?)', project_list)
    else raise 'Invalid project access mode'
    end
  end

  def websites
    case project_access_mode
    when ALL_PROJECTS then
      if project_view
        user.master_account.websites
      else
        Website.none
      end
    when PROJECTS_LIST then
      Website.where('websites.id in (?)', website_list)
    else raise 'Invalid project access mode'
    end
  end

  def text_resources
    case project_access_mode
    when ALL_PROJECTS then
      if project_view
        user.master_account.text_resources
      else
        TextResource.none
      end
    when PROJECTS_LIST then
      TextResource.where('text_resources.id in (?)', text_resource_list)
    else raise 'Invalid project access mode'
    end
  end

  def web_messages
    case project_access_mode
    when ALL_PROJECTS then
      if project_view
        user.master_account.web_messages
      else
        WebMessage.none
      end
    when PROJECTS_LIST then
      WebMessage.where('web_messages.id in (?)', web_message_list)
    else raise 'Invalid project access mode'
    end
  end

  def projects
    case project_access_mode
    when ALL_PROJECTS then
      user.master_account.projects
    when PROJECTS_LIST then
      Project.where('projects.id in (?)', project_list)
    else raise 'Invalid project access mode'
    end
  end

  def bidding_projects
    case project_access_mode
    when ALL_PROJECTS then
      if project_view
        user.master_account.bidding_projects
      else
        Revision.none
      end
    when PROJECTS_LIST then
      Revision.where('project_id in (?)', project_list)
    else raise 'Invalid project access mode'
    end
  end

  private

  def know_project?(project)
    if project.is_a? Project
      project_list.include?(project.id.to_s)
    elsif project.is_a? Website
      website_list.include?(project.id.to_s)
    elsif project.is_a? WebMessage
      web_message_list.include?(project.id.to_s)
    elsif project.is_a? TextResource
      text_resource_list.include?(project.id.to_s)
    elsif project.is_a? WebsiteTranslationContract
      website_list.include?(project.website.id.to_s)
    elsif project.is_a? Revision
      website_list.include?(project.website.id.to_s)
    else
      raise 'Unknown project class'
    end
  end

end
