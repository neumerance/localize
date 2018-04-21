module WebMessagesHelper
  def possible_message_status(attribute, sep, default)
    all_departments = '<label>' + radio_button_tag(attribute, 0, default == 0 || default.nil?) + _('Show all') + '</label> '
    res = all_departments + sep + [TRANSLATION_NEEDED, TRANSLATION_IN_PROGRESS, TRANSLATION_COMPLETE].collect do |translation_status|
      '<label>' + radio_button_tag(attribute, translation_status, translation_status == default) + WebMessage::TRANSLATION_STATUS_TEXT[translation_status] + '</label> '
    end.join(sep)
    res.html_safe
  end

  def untokanize(txt)
    txt.gsub("\n", '<br />').gsub(WebMessage::TOKEN_REGEX) { |p| content_tag(:span, p[2..-3], class: 'tokentext') }
  end

  def choose_review_for_languages(languages)
    if @user
      res = infotab_header(%w(Language Review))
      languages.each do |language|
        res += '<tr><td>' + language.name + '</td>'
        res += '<td>'
        logger.info "---------- @user=#{@user}, @web_message=#{@web_message}"
        res += managed_work_contents(@user, @web_message, false)
        res += '</td></tr>'
      end
      res += '</table>'
    else
      res = '<ul>' + (languages.collect { |l| '<li>' + l.name + '</li>' }).join + '</ul>'
    end
    res.html_safe
  end

  # used by web_messages_controller#
  def web_messages_paginated_list
    content_tag(:table, class: 'stats', style: 'width: 100%') do
      concat content_tag(:tr, class: 'headerrow') {
        concat content_tag(:th, '#')
        concat content_tag(:th, 'Name')
      }
      @web_messages.each do |web_message|
        concat content_tag(:tr) {
          concat content_tag(:td, link_to(web_message.id, controller: :web_messages, action: :show, id: web_message.id))
          concat content_tag(:td, web_message.name.blank? ? web_message.id.to_s : web_message.name)
        }
      end
    end
  end

end
