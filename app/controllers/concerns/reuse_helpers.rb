module ReuseHelpers
  def languages_and_reviewers_to_reuse(project)
    ret = {}
    project = project.revisions.last if project.is_a? Project
    project.languages.map do |l|
      ret[l] = project.reviewer_for(l)
    end
    ret
  end

  def languages_and_translators_to_reuse(project)
    ret = {}
    project = project.revisions.last if project.is_a? Project
    project.languages.map do |l|
      translator = if project.is_a? Website
                     project.representative_translator_for(l)
                   else
                     project.translator_for(l)
                   end
      ret[l] = translator if translator
    end
    ret
  end

  def projects_to_reuse
    return [] unless @user.has_client_privileges?
    if @user.is_a? Supporter
      user = @text_resource.client if @text_resource
      user = @revision.client if @revision
      user = @website.client if @website
    else
      user = @user
    end
    if user
      projects = user.projects.joins(:revisions).where('revisions.cms_request_id is NULL')
      user.text_resources + user.websites + projects
    else
      []
    end
  end
end
