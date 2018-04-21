module UsersHelper

  def infobar_contents_user(self_text, others_text, show_icon = false, icon_ok = false, icon_for_error = nil)
    content_tag(:span) do
      if @user != @auser
        others_text
      else
        if show_icon
          if icon_ok
            txt = image_tag('icons/selectedtick.png', class: 'left_icon', alt: 'ok')
          else
            icon = if icon_for_error
                     icon_for_error
                   else
                     'important.png'
                   end
            txt = image_tag("icons/#{icon}", class: 'left_icon', alt: 'warning')
          end
        else
          txt = ''
        end
        concat txt
        concat self_text.html_safe
      end
    end
  end

  def filtered_language_list(translator_languages, sameuser, show_documents)
    if sameuser || show_documents
      disp_translator_languages = translator_languages
    else
      disp_translator_languages = []
      translator_languages.each do |tl|
        disp_translator_languages << tl if tl.status == TRANSLATOR_LANGUAGE_APPROVED
      end
    end
    if !disp_translator_languages.empty?
      content_tag(:ul) do
        disp_translator_languages.each do |tl|
          if show_documents
            concat content_tag(:li) {
              concat content_tag(:b) {
                link_to(tl.language.name, controller: :supporter, action: :translator_language, id: tl.id) +
                  '<br />'.html_safe +
                  TranslatorLanguage::STATUS_TEXT[tl.status]
              }
              concat content_tag(:ul) {
                tl.translator_language_documents.each do |doc|
                  concat content_tag(:li) {
                    link_to("#{h(doc.description)}: #{doc.orig_filename}", controller: :supporter, action: :zipped_file, id: doc.id)
                  }
                end
              }
            }
          elsif sameuser || show_documents
            concat content_tag(:li, "<b>#{tl.language.name}</b>:<br />#{TranslatorLanguage::STATUS_TEXT[tl.status]}".html_safe)
          else
            concat content_tag(:li, "<b>#{tl.language.name}</b><p>#{pre_format(tl.description)}</p>".html_safe)
          end
        end
      end
    else
      '<p class="warning">No language listed yet.</p><div class="clear"></div>'.html_safe
    end

  end

  def todo_status_image(todo)
    if todo[0] == TODO_STATUS_MISSING
      src = 'icons/unselectedtick.png'
      alt = 'item needs doing'
      title = 'Your action is required.  Click to complete this task.'
    elsif todo[0] == TODO_STATUS_PENDING
      src = 'icons/selectedtick_grey.png'
      alt = 'item pending'
      title = 'This task has been started.  Click to check on the status.'
    else
      src = 'icons/selectedtick.png'
      alt = 'item done'
      title = 'This task is complete. No action is required.'
    end

    img = image_tag(src, size: '32x32', alt: alt, title: title, border: 0)
    if (todo[0] != TODO_STATUS_DONE) && todo[4]
      link_to(img, todo[3])
    else
      img
    end
  end

  def translator_languages_list(translator)
    content_tag(:ul) do
      translator.translator_languages.includes(:language).where(type: 'TranslatorLanguageTo').each do |tl|
        concat content_tag(:li) {
          concat tl.language.name + ' '.html_safe
          unless tl.status == TRANSLATOR_LANGUAGE_APPROVED
            concat content_tag(:span, '(unqualified)', class: 'warning')
          end
        }
      end
    end
  end

  def notifications_list(notifications)
    res = []
    User::NOTIFICATION_TEXT.each do |k, v|
      res << '<li>' + v[0] + '</li>' if (notifications & k) != 0
    end
    if !res.empty?
      return '<ul>' + res.join + '</ul>'
    else
      return '<p>No notifications active.</p>'
    end
  end

  def invite_translator(translator, client)
    language_jobs = client.open_jobs(translator)

    # create the language pairs for this translator
    available_jobs = []
    translator.from_languages.each do |from_language|
      translator.to_languages.each do |to_language|
        pair = [from_language, to_language]
        available_jobs += language_jobs[pair] if language_jobs.key?(pair)
      end
    end

    if translator.private_translator?
      available_jobs = language_jobs.values.flatten
    end

    unless available_jobs.empty?
      content_tag(:div, class: 'green_message', id: 'invitations') do
        concat content_tag(:h3, 'Invite the translator to your jobs')
        concat content_tag(:table, cellspacing: 0, cellpadding: 3, class: 'stats', style: 'width: 100%') {
          concat content_tag(:tr, class: 'headerrow') {
            ['Type of project', 'Project', 'Languages'].each { |th| concat content_tag(:th, th) }
          }
          available_jobs.each do |job|
            if job.class == RevisionLanguage
              kind = 'Bidding project'
              description = link_to(job.revision.project.name, controller: :revisions, action: :show, id: job.revision.id, project_id: job.revision.project.id)
              from_language = job.revision.language
              to_language = job.language
            elsif job.class == ResourceLanguage
              kind = 'Software localization'
              description = link_to(job.text_resource.name, controller: :text_resources, action: :show, id: job.text_resource.id)
              from_language = job.text_resource.language
              to_language = job.language
            elsif job.class == WebsiteTranslationOffer
              kind = 'CMS translation'
              description = link_to(job.website.name, controller: :website_translation_offers, action: :show, id: job.id, website_id: job.website.id)
              from_language = job.from_language
              to_language = job.to_language
            elsif job.class == ManagedWork
              kind = 'Review job'
              description = managed_work_link(job) # link_to('review job',{:controller=>:managed_works, :action=>:show, :id=>job.id})
              from_language = job.from_language
              to_language = job.to_language
            end
            div_id = "invite#{job.class}#{job.id}"
            invitation = link_to('Write Invitation' % translator.full_name, { action: :invite_to_job, user_id: translator.id, job_class: job.class.to_s, job_id: job.id, div: div_id, req: 'show' }, method: :post, class: 'rounded_but_orange', remote: true)
            invitation_div = content_tag(:div, '', id: div_id, style: 'clear:both')
            concat content_tag(:tr) {
              concat content_tag(:td, kind)
              concat content_tag(:td) {
                concat description
                concat '&nbsp; | &nbsp;'.html_safe
                concat invitation
                concat invitation_div
              }
              concat content_tag(:td) {
                concat from_language.name
                concat ' &raquo; '.html_safe
                concat to_language.name
              }
            }
          end
        }
      end
    end
  end

  def show_next_steps(_next_steps)
    content_tag(:div, class: 'project-steps-for-signup') do
      concat content_tag(:p) {
        content_tag(:strong, @objective) + ': '.html_safe
      }
      concat content_tag(:ol) {
        ([[content_tag(:em, _('Create account')), nil]] + @next_steps).each do |step|
          concat content_tag(:li, !step[1].blank? ? content_tag(:abbr, step[0], title: step[1]) : step[0])
        end
      }
    end
  end

  def language_pair_header(lp)
    from_name = lp.first.try(:name) || 'Undefined'
    to_name = lp.second.try(:name) || 'Undefined'
    content_tag(:h3, "From #{from_name} to #{to_name}")
  end

  def is_business_vat?(user)
    return 'Unknown' if !user.country || (!user.vat_number && user.is_business_vat.nil?)
    content_tag(:span) do
      country = Country.find(user.country_id)
      business_msg = content_tag(:b, 'Business') + ' VAT won\'t be collected as reverse-charge principle is applied.'
      non_business_msg = content_tag(:span) do
        concat content_tag(:b, 'Non-Business ')
        concat content_tag(:span, country.tax_rate.to_i) + '% '.html_safe
        concat content_tag(:span, country.name) + ' VAT will be added. This will be a plus rate according to EU regulations.'
      end
      user.is_business_vat ? business_msg : non_business_msg
    end
  end

  # used by users_controller#clients_by_source
  def users_list_reduced(users)
    content_tag(:table, class: 'stats', style: 'width: 100%') do
      concat content_tag(:tr, class: 'headerrow') {
        concat content_tag(:th, '#')
        concat content_tag(:th, 'Email')
        concat content_tag(:th, 'Nickname')
        concat content_tag(:th, 'Signup Date')
        concat content_tag(:th, 'Source')
        concat content_tag(:th, 'Actions', colspan: 2)
      }

      users.each do |user|
        concat content_tag(:tr) {
          concat content_tag(:td, user.id)
          concat content_tag(:td, user.email)
          concat content_tag(:td, link_to(user.nickname, user_path(user)))
          concat content_tag(:td, user.signup_date.to_time)
          concat content_tag(:td) {
            if !user.source.blank?
              (user.source.starts_with?('http') ? link_to(truncate(user.source[7..-1], length: 75, omission: '...'), user.source) : truncate(user.source, length: 75, omission: '...'))
            else
              ''
            end
          }
          concat content_tag(:td, link_to('Edit', edit_user_path(user)))
        }
      end
    end
  end
end
