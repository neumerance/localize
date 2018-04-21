module SupportHelper
  def support_departments(form, object, attribute)
    res = ''
    SupportDepartment.where('name NOT IN (?)', DEPARTMENTS_TO_EXCLUDE_FROM_USER_TICKETS).each do |support_department|
      res += '<label>' + form.radio_button(attribute, support_department.id) + support_department.name + '</label> '
    end
    if object.errors.include?(:support_department)
      return '<div class="fieldWithErrors">' + res + '</div>'
    else
      return res
    end
  end

  def all_support_departments(attribute, sep, default)
    all_departments = '<label>' + radio_button_tag(attribute, 0, default == 0 || default.nil?) + 'All</label> '
    (all_departments + SupportDepartment.all.collect do |support_department|
      '<label>' + radio_button_tag(attribute, support_department.id, support_department.id == default) + support_department.name + '</label> '
    end.join(sep)).html_safe
  end

  def linked_object(support_ticket)
    if support_ticket.object.class == TranslatorLanguageFrom
      link_to("translation from #{support_ticket.object.language.name}", controller: :supporter, action: :language_verifications, anchor: put_object_id(support_ticket.object)) + ' for ' + user_link(support_ticket.object.translator)
    elsif support_ticket.object.class == TranslatorLanguageTo
      link_to("translation to #{support_ticket.object.language.name}", controller: :supporter, action: :language_verifications, anchor: put_object_id(support_ticket.object)) + ' for ' + user_link(support_ticket.object.translator)
    elsif support_ticket.object.class == IdentityVerification
      link_to('identity verification', controller: :users, action: :verification, id: support_ticket.object.normal_user_id)
    elsif support_ticket.object.class == Chat
      link_to("chat on project #{support_ticket.object.revision.project.name}", controller: :chats, action: :show, project_id: support_ticket.object.revision.project_id, revision_id: support_ticket.object.revision_id, id: support_ticket.object.id)
    elsif support_ticket.object.class == Revision
      link_to("project #{support_ticket.object.project.name}", controller: :revisions, action: :show, project_id: support_ticket.object.project_id, id: support_ticket.object.id)
    elsif support_ticket.object.class == Website
      link_to("website #{support_ticket.object.name}", controller: '/wpml/websites', action: :show, id: support_ticket.object.id)
    elsif support_ticket.object.class == TextResource
      link_to("software localization project '#{support_ticket.object.name}'", controller: :text_resources, action: :show, id: support_ticket.object.id)
    elsif support_ticket.object.class == ResourceChat
      link_to("chat on software localization project '#{support_ticket.object.resource_language.text_resource.name}'", controller: :resource_chats, action: :show, id: support_ticket.object.id, text_resource_id: support_ticket.object.resource_language.text_resource.id)
    elsif support_ticket.object.class == ManagedWork
      link_to('review chat', controller: :managed_works, action: :show, id: support_ticket.object.id)
    else
      'something'
    end
  end
end
