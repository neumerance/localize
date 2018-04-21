module IssuesHelper
  def owner_link(owner)
    if owner.class == StringTranslation
      (_('String %s on Software localization project "%s"') % [
        link_to(owner.resource_string.token, controller: :resource_strings, action: :show, id: owner.resource_string.id, text_resource_id: owner.resource_string.text_resource.id),
        link_to(owner.resource_string.text_resource.name, controller: :text_resources, action: :show, id: owner.resource_string.text_resource.id)
      ]).html_safe
    elsif owner.class == WebMessage
      link_to(_('Instant translation job #%d' % owner.id), controller: :web_messages, action: :show, id: owner.id)
    elsif owner.class == RevisionLanguage
      if owner.selected_bid
        chat = owner.selected_bid.chat
        link_to(_('Project "%s"' % chat.revision.project.name), controller: :chats, action: :show, id: chat.id, revision_id: chat.revision.id, project_id: chat.revision.project.id)
      else
        link_to(_('Project "%s"' % owner.revision.project.name), controller: :revisions, action: :show, id: owner.revision.id, project_id: owner.revision.project.id)
      end
    elsif owner.class == CmsRequest
      link_to(_('Project "%s"' % owner.revision.project.name), controller: :revisions, action: :show, id: owner.revision.id, project_id: owner.revision.project.id)
    end
  end
end
