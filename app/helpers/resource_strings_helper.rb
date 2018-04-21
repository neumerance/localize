module ResourceStringsHelper
  def display_resource_strings(resource_strings, languages, orig_language)
    res = ''

    # check for reviewers
    language_reviewer = {}
    languages.each do |language|
      resource_language = @text_resource.resource_languages.where(language_id: language.id).first
      if resource_language.managed_work && (resource_language.managed_work.active == MANAGED_WORK_ACTIVE)
        language_reviewer[language] = resource_language.managed_work
      end
    end

    is_client = [@user, @user.master_account].include?(@text_resource.client)

    # issues
    stids = resource_strings.map { |rs| rs.string_translations.map(&:id) }.flatten
    all_issues = {}
    Issue.where('owner_type = ? and owner_id IN (?)', 'StringTranslation', stids).each { |i| all_issues[i.owner_id] ||= []; all_issues[i.owner_id] << i }

    resource_strings.each do |resource_string|
      res << '<tr>'
      if is_client
        res << '<td>'
        if resource_string.user_can_edit_original(@user)
          res << check_box_tag("resource_string[#{resource_string.id}]", '1', false)
        end
        res << '</td>'
      end

      res << '<td>' + h(resource_string.context) + '</td>'
      res << '<td class="label">' + link_to(h(resource_string.token), action: :show, id: resource_string.id) + '</td>'
      style = 'style="%s"' % (language_dir_css_attribute(orig_language) + text_flow_css_attribute(orig_language))
      res << '<td %s>' % style + pre_format(resource_string.txt) + '</td>'

      xlats = {}
      resource_string.string_translations.each { |st| xlats[st.language_id] = st }
      master_status = resource_string.master_string_id.blank? ? nil : STRING_TRANSLATION_DUPLICATE

      languages.each do |language|
        bg_color = StringTranslation::TRANSLATION_COLOR_CODE[master_status]
        txt = '<span class="comment">Duplicate</span>'

        if master_status
          bg_color = StringTranslation::TRANSLATION_COLOR_CODE[master_status]
          txt = '<span class="comment">Duplicate</span>'
        elsif xlats.key?(language.id)
          bg_color = if language_reviewer[language] && (xlats[language.id].status == STRING_TRANSLATION_COMPLETE) && (xlats[language.id].review_status == REVIEW_PENDING_ALREADY_FUNDED)
                       StringTranslation::TRANSLATION_COLOR_CODE[STRING_TRANSLATION_NEEDS_REVIEW]
                     else
                       StringTranslation::TRANSLATION_COLOR_CODE[xlats[language.id].status]
                     end
          txt = pre_format(xlats[language.id].txt(resource_string))
        else
          bg_color = StringTranslation::TRANSLATION_COLOR_CODE[STRING_TRANSLATION_NEEDS_UPDATE]
          txt = ''
        end

        # make sure that translation exists
        if xlats[language.id]
          issues_icon = ''
          issues = all_issues[xlats[language.id].id] || []

          unless issues.empty?
            has_open = false
            issues.each do |issue|
              if issue.status == ISSUE_OPEN
                has_open = true
                break
              end
            end
            issues_icon = has_open ? ActionController::Base.helpers.image_tag('icons/flag.png', alt: 'issues', title: 'Open issue(s)', style: 'float: right') : ActionController::Base.helpers.image_tag('icons/view.png', alt: 'issues', title: 'Resolved issue(s)', style: 'float: right')
          end
        end

        style = "style=\"background-color: #{bg_color};#{language_dir_css_attribute(language)}#{text_flow_css_attribute(language)}\""
        res << "<td #{style}>#{txt}#{issues_icon}</td>"
      end
      res << '</tr>'
    end
    res.html_safe
  end

  def language_translation(resource_string, language)
    string_translation = resource_string.string_translations.where(language_id: language.id).first
    string_translation ? string_translation.txt : ''
  end

  def formatted_original(resource_string)
    if resource_string.formatted_original
      return resource_string.formatted_original.html_safe
    end

    res = HTMLEntities.new.encode(resource_string.txt)

    # if there is a glossary, paint it
    begin
      Timeout.timeout(10) do
        res = highlight_glossary_terms(res, @glossary, @glossary_client)
      end
    rescue Timeout::Error => e
      Rails.logger.info(' ** Timeout generating highlight_glossary_terms')
    end

    if @count_mismatch
      @count_mismatch.each do |cm|
        word = h(cm[0])
        res = res.gsub(word, '<span style="background-color: #FFF0A8;">' + word + '</span>')
      end
    end

    resource_string.update_attribute :formatted_original, res
    pre_format(res, true)
  end

  # @ToDo check string_translation is a langauge, langauge_transaltion receives a langauge
  def formatted_translation(resource_string, string_translation)
    res = language_translation(resource_string, string_translation)
    res = HTMLEntities.new.encode(res)

    if @count_mismatch
      @count_mismatch.each do |cm|
        word = h(cm[0])
        res = res.gsub(word, '<span style="background-color: #FFF0A8;">' + word + '</span>')
      end
    end

    pre_format(res, true)
  end

  def translation_stats(resource_string, language)
    string_translation = resource_string.string_translations.where(language_id: language.id).first
    if !string_translation || string_translation.txt.blank?
      return 'Not translated'
    else
      return string_translation ? ("Translated on #{disp_date(string_translation.updated_at)}" + (string_translation.last_editor ? " by #{user_link(string_translation.last_editor)}" : '')) : ''
    end
  end

  def status_div(resource_string, language)
    string_translation = resource_string.string_translations.where(language_id: language.id).first
    string_translation ||= StringTranslation.new(resource_string: resource_string)
    status = string_translation ? string_translation.status : STRING_TRANSLATION_MISSING
    color = StringTranslation::TRANSLATION_COLOR_CODE[status]

    txt = if @user[:type] == 'Translator'
            StringTranslation::TRANSLATOR_STATUS_TEXT[status]
          else
            StringTranslation::STATUS_TEXT[status]
          end

    res = "<div style=\"background-color: #{color}; padding: 0.3em; margin-top: 0.5em;\">#{txt}</div>"

    if string_translation
      if string_translation.txt == resource_string.txt
        res += '<p class="warning">The translation is identical to the original text.</p>'
      elsif !string_translation.txt.blank? && string_translation.size_ratio
        if (resource_string.max_width && ((string_translation.size_ratio * 100.0) > resource_string.max_width)) ||
           (!resource_string.max_width && (resource_string.txt.length > 10) && ((string_translation.size_ratio > SIZE_RATIO_HIGH) || (string_translation.size_ratio < SIZE_RATIO_LOW)))
          res += '<p class="warning">The translation is %d%s the size of the original.</p>' % [(100.0 * string_translation.size_ratio).to_i, '%']
        end
      end
    end

    if @count_mismatch && !@count_mismatch.empty?
      res += '<div class="error_validation">'
      res += 'This string could not be completed because some required text does not match:<ul>'
      res += (@count_mismatch.collect { |cm| "<li><b>#{h(cm[0])}</b> appears #{nice_count(cm[1])} in the original and #{nice_count(cm[2])} in the translation. If you think this is a valid translation, please ask client to remove this piece of text from <b>Required Text</b> in projects' settings page..</li>" }).join
      res += '</ul></div>'
    end

    if @resource_string.max_width && string_translation.txt && string_translation.txt.mb_chars.size > @resource_string.max_width_in_chars
      res += '<div class="error_validation">'
      res += "String too long. The maximum length should be no more than #{@resource_string.max_width_in_chars} characters. </div>"
    end

    # check for mismatch arguments
    if resource_string.text_resource.check_standard_regex == 1
      if string_translation && !string_translation.argument_match?
        res += '<div class="error_validation">'
        res += if @user == resource_string.text_resource.client
                 'This text includes formatting characters (like %s and %d) which are out of order. This may cause problems for the application.'
               else
                 'This text includes formatting characters (like %s and %d). Their order must be preserved. Please correct the translation.'
               end
        res += '</div>'
      end
    end

    # review
    resource_language = resource_string.text_resource.resource_languages.where(language_id: language.id).first
    manager = nil
    if string_translation && (string_translation.status == STRING_TRANSLATION_COMPLETE) && resource_language.managed_work && (resource_language.managed_work.active == MANAGED_WORK_ACTIVE)
      manager = resource_language.managed_work.translator

      string_translation.check_enough_funds_for_review

      res += '<hr style="margin: 1em;" />'
      res += '<p>Review status: %s</p>' % ManagedWork::REVIEW_STATUS_TEXT[string_translation.review_status]

      if (string_translation.review_status == REVIEW_PENDING_ALREADY_FUNDED) && (@user == manager)
        res += form_tag({ action: :complete_review, lang_id: string_translation.language_id }, remote: true)
        res += submit_tag('Review completed', data: { disable_with: 'Review completed' })
        res += '</form>'
        res += '<p class="comment">Click to confirm that the client can use the translation.</p>'
      end

      if @user.has_supporter_privileges?
        res += form_tag(controller: :string_translations, action: :force_review, id: string_translation.id)
        res += submit_tag('mark as reviewed', data: { disable_with: 'mark as reviewed' })
        res += '</form>'

        if string_translation
          res += "<small class='comment'>RSid: #{resource_string.id}</small>"
        end
      end
    end

    # check who's the translator for this language
    translator = resource_language.selected_chat ? resource_language.selected_chat.translator : nil

    if string_translation
      potential_users = Issue.potential_users(resource_language, string_translation, @user)

      res += issues_for_object(string_translation, potential_users)
    end

    res.html_safe
  end

  def sizes_table(sizes, above_user_limit, languages, ratios)
    res = []
    ratios.each do |ratio|
      color = (ratio < (SIZE_RATIO_LOW * 10)) || (ratio > (SIZE_RATIO_HIGH * 10)) ? 'FFC0C0' : 'FFFFFF'
      style = 'style="background-color: #%s;"' % color
      row = "<tr><td #{style}>#{link_to((ratio * 10).to_s + '%', action: :index, set_args: 1, size_ratio: ratio * 10)}</td>"
      languages.each do |language|
        row += "<td #{style}>%s</td>" % sizes[language][ratio].to_s
      end
      row += '</tr>'
      # logger.info "------ row: #{row}"
      res << row
    end

    color = 'FFC0C0'
    style = 'style="background-color: #%s;"' % color
    res << "<tr><td #{style}>" + link_to('Above user defined maximal length', action: :index, set_args: 1, size_ratio: 'user') + '</td>'
    languages.each do |language|
      res << "<td #{style}>%s</td>" % above_user_limit[language].to_s
    end
    res << '</tr>'

    above_user_limit
    res.join
  end

  def nice_count(cnt)
    cnt == 1 ? 'once' : "#{cnt} times"
  end

end
