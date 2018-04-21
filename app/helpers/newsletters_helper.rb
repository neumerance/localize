module NewslettersHelper
  def show_flags(current_flags)
    content_tag(:div) do
      NEWSLETTER_FLAG_TEXT.keys.sort.each do |flag|
        concat content_tag(:label) {
          concat check_box_tag("flags[#{flag}]", 1, (current_flags & flag) != 0) + ' '.html_safe
          concat ''.html_safe + NEWSLETTER_FLAG_TEXT[flag] + '<br/>'.html_safe
        }
      end
    end
  end

  def show_active_flags(current_flags)
    released = (current_flags & NEWSLETTER_RELEASED) != 0
    sent = (current_flags & NEWSLETTER_SENT) != 0
    send_to_clients = (current_flags & NEWSLETTER_FOR_CLIENTS) != 0
    send_to_translators = (current_flags & NEWSLETTER_FOR_TRANSLATORS) != 0

    if !released
      return 'draft'
    elsif sent
      if send_to_clients && send_to_translators
        return 'sent to clients and translators'
      elsif send_to_clients
        return 'sent to clients'
      else
        return 'sent to translators'
      end
    else
      if send_to_clients && send_to_translators
        return 'pending for clients and translators'
      elsif send_to_clients
        return 'pending for clients'
      else
        return 'pending for translators'
      end
    end
  end

  def w3c_date(date)
    date.utc.strftime('%Y-%m-%dT%H:%M:%S+00:00')
  end

end
