module WebDialogsHelper
  def departments(form, object, attribute, departments)
    res = ''
    departments.each do |department|
      res += '<label>' + form.radio_button(attribute, department.id) + department.translated_name(object.visitor_language) + '</label> '
    end
    if object.errors.on(attribute)
      return '<div class="fieldWithErrors">' + res + '</div>'
    else
      return res
    end
  end

  def writer(message)
    if message.user
      message.user.full_name
    else
      @username
    end
  end

  def translation_controls_for_user(message, is_client)
    return unless is_client
    content_tag(:div) do
      concat '<br /><hr />'.html_safe
      if message.user.nil? && (message.translation_status == TRANSLATION_PENDING_CLIENT_REVIEW)
        concat form_tag({ action: :decide_about_translation, id: message.id, translate: TRANSLATION_NEEDED }, remote: true) {
          text_field_tag('do_trans', _('Request professional translation'), type: 'button')
        }
        concat form_tag({ action: :decide_about_translation, id: message.id, translate: TRANSLATION_REFUSED }, remote: true) {
          text_field_tag('dont_trans', _('Translation not needed'), type: 'button')
        }
        concat form_tag({ action: :show_self_translation, id: message.id }, remote: true) {
          text_field_tag('self_trans', _('I want to translate the message myself...'), type: 'button')
        }
      elsif message.translation_status == TRANSLATION_NEEDED
        concat content_tag(:p) {
          concat content_tag(:b, _('Message queued for translation')) + ' '.html_safe
          concat content_tag(:span, '(Job ID: ' + message.id.to_s + ')', class: 'comment')
        }
        if message.user.blank?
          concat form_tag({ action: :decide_about_translation, id: message.id, translate: TRANSLATION_REFUSED }, remote: true) {
            text_field_tag('dont_trans', _('Translation not needed'), type: 'button')
          }
        else
          concat form_tag({ action: :decide_about_translation, id: message.id, translate: TRANSLATION_NOT_NEEDED }, remote: true) {
            text_field_tag('dont_trans', _('Send without translation'), type: 'button')
          }
        end
      elsif message.translation_status == TRANSLATION_IN_PROGRESS
        concat content_tag(:p) {
          concat content_tag(:b, _('Message being translated')) + ' '.html_safe
          concat content_tag(:span, '(Job ID: ' + message.id.to_s + ')')
        }
      elsif message.translation_status == TRANSLATION_COMPLETE
        if message.user.nil?
          concat form_tag({ action: :show_self_translation, id: message.id }, remote: true) {
            text_field_tag('self_trans', _('Edit translation'), type: 'button')
          }
          if message.translator_id.nil?
            concat form_tag({ action: :decide_about_translation, id: message.id, translate: TRANSLATION_NEEDED }, remote: true) {
              text_field_tag('do_trans', _('Request professional translation'), type: 'button')
            }
          end
        else
          concat form_tag({ action: :show_translation, id: message.id }, remote: true) {
            text_field_tag('show_translation', _('Show translation'), type: 'button')
          }
        end
      elsif message.translation_status == TRANSLATION_REFUSED
        concat form_tag({ action: :decide_about_translation, id: message.id, translate: TRANSLATION_PENDING_CLIENT_REVIEW }, remote: true) {
          text_field_tag('do_trans', _('Undo translation not needed'), type: 'button')
        }
      end
    end
  end

  def message_translation_status(dialog, is_client)
    return if !is_client || (dialog.visitor_language_id == dialog.client_department.language_id)
    default = dialog.client_department.translation_status_on_create
    res = '<label>' + radio_button_tag(:translation_status, TRANSLATION_NEEDED, default == TRANSLATION_NEEDED) + _('This message should be professionally translated') + '</label><br />'
    res += '<label>' + radio_button_tag(:translation_status, TRANSLATION_NOT_NEEDED, default == TRANSLATION_NOT_NEEDED) + _('Send this message without translation') + '</label><br />'
    res += '<br />'
    res
  end

  def untokanize_if_client(txt, is_client)
    if is_client
      txt.gsub(WebMessage::TOKEN_REGEX) { |p| "<span class=\"tokentext\">#{p[2..-3]}</span>" }
    else
      txt
    end
  end

end
