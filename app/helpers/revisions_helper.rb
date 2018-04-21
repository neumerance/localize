module RevisionsHelper

  def closing_time(revision)
    if revision.bidding_close_time && (revision.bidding_close_time < Time.now)
      "This project is closed for bidding (bidding closed on #{disp_time(revision.bidding_close_time)})."
    elsif revision.open_translation_languages.empty?
      'All languages in this project have been assigned to translators already.'
    elsif revision.bidding_close_time
      "This project is open to bids. Bidding closes on #{disp_time(revision.bidding_close_time)}."
    else
      "This project will be available to bidding for #{@revision.bidding_duration} days once it is released."
    end
  end

  def bids_summary(revision_language, bid_units)
    content_tag(:span) do
      if revision_language.selected_bid
        concat content_tag(:span) do
          concat 'Selected bid: '.html_safe; concat ' '.html_safe
          concat content_tag(:span, revision_language.selected_bid.amount); concat ' '.html_safe
          concat content_tag(:span, revision_language.selected_bid.currency.name); concat content_tag(:span, bid_units)
        end
        if @user.has_supporter_privileges?
          concat ' '.html_safe
          concat link_to(_('Money Account'), controller: :finance, action: :account_history, id: revision_language.selected_bid.account.id)
          concat ' '.html_safe
          concat '<br/>Balance: '.html_safe
          concat content_tag(:span, revision_language.selected_bid.account.balance)
          concat ' USD'
        end
      elsif revision_language.valid_bids.length == 1
        concat '1 bid given for '.html_safe
        concat revision_language.bids[0].amount; concat ' '.html_safe
        concat revision_language.bids[0].currency.name; concat bid_units
      elsif revision_language.valid_bids.length > 1
        amounts = []
        revision_language.valid_bids.each { |bid| amounts << bid.amount }
        concat content_tag(:span, revision_language.valid_bids.length)
        concat ' bids from '.html_safe
        concat content_tag(:span, amounts.min)
        concat ' to '.html_safe
        concat content_tag(:span, amounts.max); concat ' '.html_safe
        concat content_tag(:span, revision_language.bids[0].currency.name)
        concat content_tag(:span, bid_units)
      else
        'No bids given'
      end
    end
  end

  def revision_languages_summary(user, revision, sis_stats = nil)
    content_tag(:div) do
      bid_units = (revision.kind == TA_PROJECT) || (revision.kind == SIS_PROJECT) ? ' / word' : ''

      if !revision.revision_languages.empty?

        reviewing = (@user[:type] == 'Translator') && @user.managed_works.where('(managed_works.owner_type=?) AND (managed_works.owner_id IN (?)) AND (managed_works.active in (?))', 'RevisionLanguage', revision.revision_languages.collect(&:id), [MANAGED_WORK_ACTIVE, MANAGED_WORK_PENDING_PAYMENT]).first

        fields = %w(Language Status Bids)

        fields << 'Word count' if sis_stats

        if @user.has_client_privileges? || @user.has_supporter_privileges?
          fields += %w(Translators Reviewers)
        elsif reviewing
          fields << 'Translator'
        end

        concat content_tag(:table, cellspacing: 0, cellpadding: 3, class: 'stats', width: '100%') {
          concat content_tag(:tr, class: 'headerrow') {
            fields.each { |x| concat content_tag(:td, x) }
          }
          for revision_language in revision.revision_languages.includes(:language, :selected_bid)
            concat content_tag(:tr) {
              concat content_tag(:td, content_tag(:strong, revision_language.language&.nname))
              concat content_tag(:td) {
                if revision_language.selected_bid
                  if revision_language.selected_bid.status == BID_COMPLETED
                    concat 'Work has been completed'.html_safe
                  elsif revision_language.selected_bid.status == BID_TERMINATED
                    concat 'Work has been terminated'.html_safe
                  elsif revision_language.selected_bid.status == BID_DECLARED_DONE
                    if revision_language.managed_work && (revision_language.managed_work.active == MANAGED_WORK_ACTIVE)
                      if revision_language.managed_work.translation_status == MANAGED_WORK_COMPLETE
                        concat 'Translation and review complete.'.html_safe
                        if @user == @project.client
                          concat '<br />'.html_safe
                          concat content_tag(:span, class: 'warning') {
                            concat 'Go to the '.html_safe
                            concat link_to('project chat', controller: :chats, action: :show, project_id: revision.project_id, revision_id: revision.id, id: revision_language.selected_bid.chat.id)
                            concat ' and accept the work as complete.'.html_safe
                          }
                        end
                      elsif revision_language.managed_work.translation_status == MANAGED_WORK_WAITING_FOR_REVIEWER
                        concat 'Translation complete. Waiting for a reviewer.'.html_safe
                      elsif revision_language.managed_work.translation_status == MANAGED_WORK_REVIEWING
                        concat 'Translation complete. Review in progress.'.html_safe
                      end
                    else
                      concat 'Translation is complete'.html_safe
                    end
                  elsif user.id == revision_language.selected_bid.chat.translator_id
                    concat content_tag(:strong, 'Your bid to translated in this language was selected.')
                  elsif revision_language.selected_bid.status == BID_WAITING_FOR_PAYMENT
                    concat content_tag(:span, 'Waiting for escrow deposit ', class: 'warning')
                    if @user.has_client_privileges? && revision_language.selected_bid.try(:account).try(:credits).try(:any?)
                      concat form_tag({ controller: :chats, action: :check_invoice_status, project_id: revision.project_id, revision_id: revision.id, id: revision_language.selected_bid.chat.id, bid_id: revision_language.selected_bid.id, lang_id: revision_language.language.id }, remote: true) {
                        submit_tag('Check status', data: { disable_with: 'Check status' })
                      }
                    end
                  else
                    concat 'Being done '.html_safe
                    if (user.id == revision.project.client_id) && (revision.kind == TA_PROJECT)
                      done_percentage = revision_language.completed_percentage
                      concat ' ('.html_safe
                      concat content_tag(:b, done_percentage)
                      concat ' completed) '.html_safe
                    end
                  end
                  if @user.has_admin_privileges?
                    concat '<br />'.html_safe
                    concat link_to('Chat between client and translator', controller: :chats, action: :show, project_id: revision.project_id, revision_id: revision.id, id: revision_language.selected_bid.chat.id)
                  end
                else
                  concat 'Not assigned to a translator'.html_safe
                end
              }

              # -------------- "Reviewers" column ---------------
              # Review controls for translators
              concat content_tag(:td) {
                concat bids_summary(revision_language, bid_units)
                if (@user[:type] == 'Translator') && revision_language.managed_work &&
                   [MANAGED_WORK_ACTIVE, MANAGED_WORK_PENDING_PAYMENT].include?(revision_language.managed_work.active)
                  if revision_language.managed_work.translator == @user
                    content_tag(:p, content_tag(:b, 'You are the reviewer'))
                  elsif !revision_language.managed_work.translator && revision_language.managed_work.translator_can_apply_to_review(@user)
                    concat '<br /><br />'.html_safe
                    concat button_to('Become the reviewer for this job', { controller: :managed_works, action: :be_reviewer, id: revision_language.managed_work.id }, 'data-confirm' => 'Are you sure? You will need to review the translation as soon as it completes. Also, keep in mind that if you become the reviewer, you cannot be selected as the translator for this project.')
                  end
                end
              }
              if sis_stats
                stats = sis_stats[revision_language.language]
                words_to_translate = (stats[WORDS_STATUS_NEW_CODE] || 0) + (stats[WORDS_STATUS_MODIFIED_CODE] || 0)
                concat content_tag(:td, words_to_translate)
              end

              # Review controls for clients and supporters
              if user.has_client_privileges? || user.has_supporter_privileges?
                concat content_tag(:td) {
                  if revision_language.selected_bid
                    concat 'Translator:'.html_safe
                    concat ' | '.html_safe
                    concat user_link(revision_language.selected_bid.chat.translator)
                    if [BID_ACCEPTED, BID_TERMINATED, BID_DECLARED_DONE].include?(revision_language.selected_bid.status)
                      concat '<br /><br />'.html_safe
                      concat link_to('respond to bid',
                                     { controller: :chats, action: :show, id: revision_language.selected_bid.chat.id, revision_id: @revision.id, project_id: @project.id },
                                     style: 'font-weight:bold;')
                      concat '<br /><br />'.html_safe
                    else
                      concat chat_link(revision_language.selected_bid.chat, 'Chat with translator', 'reply')
                    end
                  else
                    unless revision_language.valid_bids.empty?
                      concat 'Bids for this language:<br />'.html_safe
                      concat content_tag(:p) {
                        for bid in revision_language.valid_bids
                          comment = if bid.status == BID_REFUSED
                                      ' (refused) '
                                    elsif bid.status == BID_CANCELED
                                      ' (canceled) '
                                    else
                                      ''
                                    end
                          concat ' by '.html_safe; concat user_link(bid.chat.translator); concat ' for '.html_safe
                          concat bid.amount; concat ' '.html_safe; concat bid.currency.disp_name; concat ' '.html_safe; concat comment

                          concat link_to('respond&nbsp;to&nbsp;bid'.html_safe,
                                         { controller: :chats, action: :show, id: bid.chat.id, revision_id: @revision.id, project_id: @project.id },
                                         style: 'font-weight: bold;')
                          concat '<br />'.html_safe
                        end
                      }
                    end
                    if user.can_modify?(revision.project)
                      url = { action: :invite_translator, revision_language_id: revision_language.id }
                      url[:in_behalf_of] = @project.client_id if @user.has_supporter_privileges?
                      concat content_tag(:p, link_to('Invite translators', url))
                    end
                  end
                }
                concat content_tag(:td) {
                  concat managed_work_controls(@user, revision_language, false, true)
                }
              elsif reviewing
                concat content_tag(:td) {
                  is_reviewer = revision_language.managed_work && (revision_language.managed_work.active == MANAGED_WORK_ACTIVE) && (revision_language.managed_work.translator == @user)
                  if is_reviewer && revision_language.selected_bid
                    concat content_tag(:p, 'Translator: '.html_safe + user_link(revision_language.selected_bid.chat.translator))
                    concat content_tag(:p, chat_link(revision_language.selected_bid.chat, 'Chat between client and translator'))
                  end
                }
              end
            }
          end
        }
      else
        concat content_tag(:table, class: 'stats', width: '100%', cellspacing: 0, cellpadding: 3) {
          concat content_tag(:tr, content_tag(:td, content_tag(:p, 'No translation languages selected yet.', class: 'warning')))
        }
      end
    end
  end

  def language_name_from_id(lang_id)

    lang = Language.find(lang_id)
    lang.name
  rescue
    'Unknown language'

  end

  def auto_accept_status(user, revision)
    if !revision.auto_accept_amount || (revision.auto_accept_amount == 0)
      return 'Not set'
    end

    is_client = user.id == revision.project.client_id
    required_amount = if is_client
                        revision.missing_amount_for_auto_accept_for_all_languages
                      elsif user.is_translator?
                        user_languages_ids = user.to_languages.pluck(:id)
                        revision_language = revision.revision_languages.select do |rl|
                          user_languages_ids.include? rl.language_id
                        end.first
                        revision_language&.missing_amount_for_auto_accept || 0
                      else
                        0
                      end

    if !is_client && (required_amount > 0)
      'Not available'
    else
      content_tag(:span) do
        concat revision.auto_accept_amount
        concat ' '.html_safe
        concat revision.currency.disp_name.html_safe
        concat ' '.html_safe
        revision.payment_units
      end
    end
  end

  def payment_for_auto_accept(user, revision)
    content_tag(:div) do
      if (user.id == revision.project.client_id) && revision.auto_accept_amount && (revision.auto_accept_amount > 0)
        required_amount = revision.missing_amount_for_auto_accept_for_all_languages
        if required_amount > 0
          concat content_tag(:div, class: 'errorExplanation') {
            concat content_tag(:h3, 'Not enough balance to automatically accept bids')
            concat content_tag(:p) {
              concat 'You\'ve chosen to automatically accept bids of '.html_safe; concat revision.auto_accept_amount; concat ' '.html_safe; concat revision.currency.disp_name; concat ' '.html_safe; concat revision.payment_units; concat '. '.html_safe
              concat 'To be enabled, your balance must be able to fund this project.'.html_safe
            }
            concat form_tag({ action: :add_required_amount_for_auto_accept, id: revision.id }, remote: true) {
              submit_tag('Deposit the required amount (%.2f %s)' % [required_amount, revision.currency.name], data: { disable_with: 'Please wait ...' })
            }
          }
        end
      end
    end
  end

  def original_language_text(revision)
    content_tag(:span) do
      if revision.language_id.blank? || revision.language_id.zero?
        concat 'You must first select the language to translate from'
      elsif revision.released != 1
        concat 'The original language of the texts in this project is '.html_safe
        concat content_tag(:strong, content_tag(:span, @revision.language.name, class: 'txtblack'))
        concat '. Select the languages to be translated to.'.html_safe
      else
        concat 'The texts for translation in this project need to be translated from '.html_safe
        concat content_tag(:strong, content_tag(:span, @revision.language.name, class: 'txtblack'))
        concat ' to these languages.'.html_safe
      end
    end
  end

  def print_stats(dict, language_id, single_txt, multiple_txt)
    res = ''
    if dict
      disp_languages = if language_id && dict.key?(language_id)
                         [language_id]
                       else
                         dict.keys
                       end
      disp_languages.each do |lang_id|
        dict[lang_id].each do |status, count|
          res += "<b>#{count} #{WORDS_STATUS_TEXT[status]}</b> #{count == 1 ? single_txt : multiple_txt} in <b>#{language_name_from_id(lang_id)}</b><br />"
        end
      end
    end
    res
  end

  def list_translators_to_invite(translators)
    content_tag(:div) do
      translators.each do |translator|
        concat content_tag(:div, class: 'translator_profile') {
          concat content_tag(:h3, link_to(translator.full_name + (!translator.country.blank? ? ', %s' % translator.country.name : ''), controller: :users, action: :show, id: translator.id))
          concat content_tag(:table) {
            content_tag(:tr) do
              concat content_tag(:td, image_for_user(translator), class: 'translator_image')
              concat content_tag(:td, class: 'translator_bio') {
                if translator.bionote && !translator.bionote.body.blank?
                  content_tag(:p, style: 'padding-top:0; margin-top:0', class: 'quote') do
                    concat '&ldquo;'.html_safe; concat pre_format(sanitize(translator.bionote.i18n_txt(@locale_language)), true); concat '&rdquo;'.html_safe
                  end
                end
              }
            end
          }
          concat content_tag(:p) {
            concat 'Rating: '.html_safe; concat translator.rating.to_i; concat ' Recommendations by clients: '.html_safe; concat translator.markings.length
          }
          chat = @revision.chats.where(translator_id: translator.id).first
          if chat
            concat 'Already invited - '.html_safe; concat link_to('chat', controller: :chats, action: :show, id: chat.id, revision_id: @revision.id, project_id: @project.id)
          else
            concat button_to('Invite to project', { controller: :chats, action: :create, revision_id: @revision.id, project_id: @project.id, translator_id: translator.id, in_behalf_of: params[:in_behalf_of] }, :style => 'padding: 0.5em 1em;', 'data-confirm' => "Are you sure you want to invite #{translator.full_name} to this project?")
          end
        }
      end
    end
  end

end
