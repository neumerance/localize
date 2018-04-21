module SupporterHelper
  def cms_clients_table(clients)
    res = infotab_header(%w(Client Projects Kind Jobs))
    client_keys = clients.keys.sort.reverse
    client_keys.each do |client|
      websites = clients[client]
      website_count = websites.length
      if website_count > 10
        have_more_projects = true
        website_count = 10
      else
        have_more_projects = false
      end
      first_project = true
      res += "<tr><td rowspan=\"#{website_count}\">#{user_link(client[1])}"
      if have_more_projects
        res += "<br /><p><b>This client has #{websites.length} projects</b></p>"
      end
      res += '</td>'
      websites[0...website_count].each do |website|
        res += '<tr>' unless first_project
        res += '<td>' + link_to(website.name, controller: '/wpml/websites', action: :show, id: website.id) + '</td>'
        res += "<td>#{WEBSITE_DESCRIPTION[website.cms_kind]}: <b>#{Website::PROJECT_KIND_TEXT[website.project_kind]}</b></td><td>#{website.cms_requests.count}</td>"
        res += '</tr>'
        first_project = false
      end
    end
    res += '</table>'
    res
  end

  def background_for_paying_user(user)
    paying = false
    user.money_accounts.each do |money_account|
      paying = true unless money_account.credits.empty?
    end
    paying ? ' style="background-color: #FFE0E0;"' : ''
  end

  def project_and_client_name
    res = '<div class="subframe">' + form_tag(action: :apply_search_filter)
    res += 'Project name: ' + text_field_tag(:project_name, @project_name, size: 20) + ' &nbsp; Client name: ' + text_field_tag(:client_name, @client_name, size: 20)
    res += ' &nbsp; Category: ' + select_tag(:category_id, options_for_select(Category.list, @category_id))
    res += ' &nbsp; ' + submit_tag('Search', data: { disable_with: 'Processing...' })
    res += hidden_field_tag(:continue_to, action_name)
    res += '</form>'
    if !@project_name.blank? || !@client_name.blank? || !@category_id.blank?
      res += ' &nbsp; ' + button_to('Clear search', action: :apply_search_filter, continue_to: action_name)
    end

    res += '</div>'
    res.html_safe
  end

  def translator_auto_assign_button(translator, assigned_translators_ids)
    auto_assign_button(translator, assigned_translators_ids, 'translator')
  end

  def reviewer_auto_assign_button(translator, assigned_reviewers_ids, review_enabled)
    return content_tag(:span, 'Review Disabled') unless review_enabled
    return content_tag(:span, "Level #{translator[:level]} Translator") unless translator[:level] == 2
    auto_assign_button(translator, assigned_reviewers_ids, 'reviewer')
  end

  def auto_assign_button(translator, assigned_ids, type)
    link = url_for controller: '/supporter', action: :assign_assignment_type, id: translator[:id], assignment_type: type
    exists = assigned_ids.include? translator[:id]
    link_to "Assign as #{type}", link,
            class: "btn btn-xs #{get_auto_assign_button_class(exists)} #{type} #{exists ? 'disabled' : ''}", remote: true
  end

  private

  def get_auto_assign_button_class(exists = false)
    exists ? 'btn-success' : 'btn-default'
  end

end
