module TranslatorsHelper
  def translation_languages(translator)
    content_tag(:span) do
      cnt = 0
      show_more = false
      translator.from_languages.each do |from_lang|
        translator.to_languages.each do |to_lang|
          if cnt == 4
            show_more = true
            break
          end
          concat content_tag(:p, link_to('%s to %s' % [from_lang.name, to_lang.name], action: :from, id: from_lang.name, to: to_lang.name))
          cnt += 1
        end
      end
      if show_more
        concat link_to('More translation languages', action: :show, id: translator.id)
      end
    end
  end

end
