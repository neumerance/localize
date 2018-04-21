module WebSupportsHelper
  def client_support_departments_html(web_support, selected_department = nil)
    res = ''
    single = true
    if selected_department
      res = "&lt;input id=&quot;web_dialog_client_department_id&quot; type=&quot;hidden&quot; value=&quot;#{selected_department.id}&quot; name=&quot;web_dialog[client_department_id]&quot; /&gt;\n"
    elsif web_support.client_departments.length == 1
      res = "&lt;input id=&quot;web_dialog_client_department_id&quot; type=&quot;hidden&quot; value=&quot;#{web_support.client_departments[0].id}&quot; name=&quot;web_dialog[client_department_id]&quot; /&gt;\n"
    else
      res += '<br />'
      web_support.client_departments.each do |client_department|
        res += '&nbsp;&nbsp;&lt;label&gt;'
        res += "&lt;input id=&quot;web_dialog_client_department_id_#{client_department.id}&quot; type=&quot;radio&quot; value=&quot;#{client_department.id}&quot; name=&quot;web_dialog[client_department_id]&quot; /&gt;&amp;nbsp;"
        res += client_department.name.to_s
        res += "&lt;/label&gt;\n"
      end
      single = false
    end
    if single
      return "&lt;td colspan=&quot;2&quot;&gt;#{res}&lt;/td&gt;"
    else
      return "&lt;td&gt;Department:&lt;/td&gt;&lt;td&gt;#{res}&lt;/td&gt;"
    end
  end

  def all_client_departments(attribute, sep, default, client_departments, all_label)
    all_departments = '<label>' + radio_button_tag(attribute, 0, default == 0 || default.nil?) + all_label + '</label> '
    all_departments + sep + client_departments.collect do |client_department|
      '<label>' + radio_button_tag(attribute, client_department.id, client_department.id == default) + client_department.name + '</label> '
    end.join(sep)
  end

  def client_department_translations(client_department)
    if client_department.db_content_translations.empty?
      _('None yet')
    else
      '<ul>' + (client_department.db_content_translations.collect { |translation| "<li>#{translation.language.name}: #{translation.txt}</li>" }).join + '</ul>'
    end
  end

  def web_support_stats(web_support)
    res = []
    pending_count = web_support.pending_web_dialogs.count
    total_count = web_support.web_dialogs.count
    if pending_count > 0
      res << '<img src="/assets/icons/important_16_gray.png" width="16" height="16" alt="important" style="vertical-align: top;" /> <span class="warning">' + link_to(_('%d pending tickets') % pending_count, action: :show, id: web_support.id) + '</span>'
    end
    if total_count > 0
      res << link_to(_('%d total') % total_count, action: :browse_tickets, id: web_support.id, set_args: 1)
    end
    res.join(' | ')
  end

end
