module ClientHelper
  def low_funding_message(unfunded_web_messages)
    content_tag(:span) do
      concat 'There are '
      missing = []
      missing << link_to(pluralize(unfunded_web_messages.length, 'instant translation job'), controller: :web_messages, action: :index, translation_status: TRANSLATION_NEEDED, set_args: 1)
      missing.each { |link| concat link; ' and '.html_safe unless link == missing.last }
      concat ' that has no enough funding to complete them.'
    end
  end
end
