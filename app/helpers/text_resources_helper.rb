module TextResourcesHelper
  def resource_languages_summary(text_resource, user)
    content_tag(:div) do
      is_client = [user, user.master_account].include?(text_resource.client)
      can_modify = user.is_client? && user.can_modify?(text_resource)
      is_supporter = user.has_supporter_privileges?
      status = nil
      translator = nil

      if !text_resource.resource_languages.empty?
        money_account = nil
        if is_client
          money_account = user.find_or_create_account(DEFAULT_CURRENCY_ID)
        end
        missing_funds = []
        total_cost = 0

        fields = if is_client
                   ['Language', 'Translators', 'Translation status', 'Output filename', 'Send translations']
                 elsif is_supporter
                   ['Language', 'Translators', 'Translation status', 'Output filename', 'Sent translations']
                 else
                   ['Language', 'Translators', 'Translation status']
                 end

        # @Todo this method is heavy if project is big.
        # @ToDO used for missing funding
        stats = text_resource.translation_completion
        resource_languages = text_resource.resource_languages.joins(:language).includes(:selected_chat).order('languages.name')

        concat '<br />'.html_safe
        if @user.has_supporter_privileges?
          concat content_tag(:div, style: 'text-align: right; margin-bottom:5px') {
            form_tag(action: :update_word_counts) do
              button_tag('Recalculate word count')
            end
          }
        end

        if is_client && can_modify
          concat '<br />'.html_safe
          concat content_tag(:p, style: 'text-align: right') {
            concat link_to 'Select all languages', 'javascript:void(0)', onclick: 'toggleAllTickbox()', style: 'margin-right: 20px', class: 'tickToggler', data: { status: 0 }
            concat text_field_tag(:begin_translations, 'Begin marked translations', disabled: 'disabled', onclick: "confirm_send_translations('Are you sure you want to begin the marked translation jobs?', 'selected_chats[]', #{text_resource.id})", type: 'button', class: 'submit_chat')
          }
        end

        concat content_tag(:table, cellspacing: 0, cellpadding: 3, class: 'stats', width: '100%', id: 'resource_languages') {
          concat content_tag(:tr, class: 'headerrow') {
            fields.each { |th| concat content_tag(:th, th) }
          }
          resource_languages.each do |resource_language|
            review_cost = nil
            review_wc = 0
            status = nil
            wc = resource_language.count_untraslated_words
            if resource_language.selected_chat
              if is_client || is_supporter
                translator = content_tag(:span) do
                  translator_user = resource_language.selected_chat.translator
                  link_disp = content_tag(:span) do
                    concat 'Communicate with translator '.html_safe
                    concat '('.html_safe
                    concat content_tag(:span, translator_user.try(:full_name))
                    concat vacation_text(translator_user)
                    concat ')'.html_safe
                  end
                  concat link_to(link_disp, controller: :resource_chats, action: :show, text_resource_id: text_resource.id, id: resource_language.selected_chat.id)
                end
                status = content_tag(:div) do
                  concat content_tag(:b, 'Translation Status')
                  concat content_tag(:ul) {
                    concat content_tag(:li, 'Words funded, waiting for translation: %d' % resource_language.selected_chat.word_count)
                    concat content_tag(:li, 'Words not funded: %d' % wc)
                  }

                  if resource_language.review_enabled?
                    concat content_tag(:b, 'Review Status')

                    concat content_tag(:ul) {
                      paid_review_wc = resource_language.funded_words_pending_review_count(false)
                      concat content_tag(:li, 'Words funded, waiting for review: %d' % paid_review_wc)
                      review_wc = resource_language.unfunded_words_pending_review_count(false)
                      concat content_tag(:li, 'Words not funded: %d' % review_wc)
                    }
                  end

                  if is_client
                    private_translator = begin
                                           resource_language.selected_chat.translator.private_translator?
                                         rescue
                                           false
                                         end

                    needs = ActiveSupport::OrderedHash.new
                    needs[:translation] = wc > 0
                    needs[:review] = resource_language.review_enabled? && (review_wc > 0 || wc > 0)
                    checkbox_amount = (resource_language.cost < 0 ? 0 : resource_language.cost.ceil_money)

                    needs_text = needs.find_all { |_k, v| v == true }.map { |k, _v| k }
                    case needs_text.size
                    when 1
                      checkbox_label = 'Ready to start %s (%d words, %.2f USD)' % (needs_text + [wc, checkbox_amount])
                      funding_message = '%s to %s' % (needs_text + [resource_language.language.name])
                    when 2
                      checkbox_label = 'Ready to start %s and %s (%d words, %.2f USD)' % (needs_text + [wc, checkbox_amount])
                      funding_message = '%s and %s to %s' % (needs_text + [resource_language.language.name])
                    when 3
                      checkbox_label = 'Ready to start %s and %s with %s (%d words, %.2f USD)' % (needs_text + [wc, checkbox_amount])
                      funding_message = '%s, %s and %s to %s' % (needs_text + [resource_language.language.name])
                    end

                    if private_translator && needs[:translation]
                      funding_message.gsub! 'translation and ', ''
                    end

                    if money_account && needs[:translation]
                      total_cost += resource_language.cost.ceil_money

                      if money_account.balance >= resource_language.cost
                        concat '<br />'.html_safe
                        concat check_box_tag('selected_chats[]', resource_language.selected_chat.id, false, checked: false, onclick: 'toggleTickboxes()', class: 'sel_chat', id: "selected_chats_#{resource_language.language_id}")
                        concat label_tag('selected_chats[]', checkbox_label, id: "chat_#{resource_language.language_id}_label", style: 'color:darkgreen; font-weight:bold; font-size:14px', for: "selected_chats_#{resource_language.language_id}")
                        concat '<br /><br />'.html_safe
                      end

                      if needs[:translation] && needs[:review]
                        transfer = TRANSFER_DEPOSIT_TO_RESOURCE_TRANSLATION_WITH_REVIEW
                      elsif needs [:translation]
                        transfer = TRANSFER_DEPOSIT_TO_RESOURCE_TRANSLATION
                      else
                        raise "Don't need something? #{needs.inspect}"
                      end

                      missing_funds << [resource_language, funding_message, resource_language.cost.ceil_money, transfer]
                      # Review only
                    elsif needs[:review]
                      total_cost += resource_language.review_cost.ceil_money
                      if money_account.balance > resource_language.review_cost
                        concat '<br />'.html_safe
                        concat content_tag(:div, style: 'maring-bottom:10px') {
                          link_to_remote(
                            'Review Translation (%d words, %.2f USD)' % [resource_language.unfunded_words_pending_review_count(false), resource_language.review_cost],
                            { controller: :resource_chats, action: :start_review, text_resource_id: text_resource.id, id: resource_language.selected_chat.id },
                            :style => 'padding: 0.5em 1em;',
                            'data-confirm' => 'Are you sure you want to begin this review job?',
                            class: 'rounded_but_orange', method: :post
                          )
                        }
                      else
                        concat link_to('Pay for %s' % funding_message, anchor: 'missing_funds'); concat '<br />'.html_safe
                      end
                      # icldev-176
                      #  the original value was resource_language.review_cost
                      # this doesn't look right, reverting this back to resource_language.review_cost from resource_language.cost # emartini 18/04/2017
                      missing_funds << [resource_language, funding_message, resource_language.review_cost.ceil_money, TRANSFER_DEPOSIT_TO_RESOURCE_REVIEW]
                    end
                  end

                  resource_account = resource_language.find_or_create_account(DEFAULT_CURRENCY_ID)
                  concat content_tag(:div, '', id: "resource_account_#{resource_account.id}") {
                    resource_account_form(resource_account)
                  }
                end
                # when the reviewer status is changed, full page refresh is needed
              else
                translator = content_tag(:span) do
                  concat 'Translator: '.html_safe
                  concat user_link(resource_language.selected_chat.translator)
                  if resource_language.selected_chat.translator == user
                    concat '. '.html_safe; concat link_to('Communicate with client', controller: :resource_chats, action: :show, text_resource_id: text_resource.id, id: resource_language.selected_chat.id)
                  elsif resource_language.review_enabled? && (resource_language.managed_work.translator == user)
                    concat '. '.html_safe; concat link_to('Communication between the client and translator', controller: :resource_chats, action: :show, text_resource_id: text_resource.id, id: resource_language.selected_chat.id)
                  end
                end
              end
            else
              translator = content_tag(:div) do
                concat content_tag(:p, 'Not assigned to a translator')
                if is_client || is_supporter
                  pending_chats = resource_language.resource_chats.where('resource_chats.status != ?', RESOURCE_CHAT_DECLINED)
                  unless pending_chats.empty?
                    concat '<br />You have started communication with the following translators:<br />'.html_safe
                    concat content_tag(:ul) {
                      check_id = 1
                      pending_chats.each do |resource_chat|
                        concat content_tag(:li) {
                          concat user_link(resource_chat.translator); concat ' - '.html_safe
                          concat link_to('Communicate with %s' % resource_chat.translator.full_name, controller: :resource_chats, action: :show, text_resource_id: text_resource.id, id: resource_chat.id)
                          concat ' - '.html_safe; concat content_tag(:span, (!resource_chat.translator.country.blank? ? resource_chat.translator.country.name + ', ' : '') + '%d recommendations' % resource_chat.translator.markings.count, class: 'comment')
                          if resource_chat.status != RESOURCE_CHAT_APPLIED
                            concat content_tag(:span, '(not applied yet)', class: 'comment')
                          end
                        }
                        check_id += 1
                      end
                    }
                  end
                  declined_applications = resource_language.resource_chats.where('resource_chats.status = ?', RESOURCE_CHAT_DECLINED)
                  unless declined_applications.empty?
                    concat '<br />You have declined these applications:'.html_safe
                    concat content_tag(:ul) {
                      declined_applications.each do |resource_chat|
                        concat content_tag(:li, link_to('Communicate with %s' % resource_chat.translator.full_name, controller: :resource_chats, action: :show, text_resource_id: text_resource.id, id: resource_chat.id))
                      end
                    }
                  end

                  if resource_language.status == RESOURCE_LANGUAGE_OPEN
                    if resource_language.sent_notifications.count == 0
                      concat content_tag(:p) {
                        concat 'Translators not notified yet '.html_safe
                        concat content_tag(:span, '(we will be sending notifications to translators about your project very soon)', class: 'comment')
                      }
                    else
                      notified_translators = resource_language.sent_notifications.map { |notification| Translator.find(notification.user_id) }
                      qualified_translators = 0
                      notified_translators.each do |u|
                        qualified_translators += 1 if u.userstatus == USER_STATUS_QUALIFIED
                      end
                      concat content_tag(:p, qualified_translators.to_s + ' qualified translators were notified')
                      concat content_tag(:div, style: 'margin-bottom: 30px') {
                        if can_modify
                          link_to_remote(
                            'Resend notifications',
                            { action: :clear_notifications, resource_language_id: resource_language.id },
                            'data-confirm' => "Are you sure you want to resend these notifications.\nPlease only use this if you've made changes to the project.",
                            :html => { class: 'rounded_but_orange' }
                          )
                        end
                      }
                    end
                    concat content_tag(:div, style: 'padding-top: 5px; float: right') {
                      if can_modify
                        link_to_remote(
                          'Close to translators',
                          { action: :update_language_status, status: RESOURCE_LANGUAGE_CLOSED, resource_language_id: resource_language.id },
                          'data-confirm' => 'Are you sure you want to close this language to translators? Translators will not be notified about this project and cannot apply to it.',
                          class: 'rounded_but_orange', style: 'float: right;', method: :post
                        )
                      end
                    }
                  else
                    concat content_tag(:p) {
                      concat 'This language is '.html_safe
                      concat content_tag(:b, 'closed')
                      concat ' to translators. You can still send invitations, but other translators cannot apply to it.'.html_safe
                    }
                    concat content_tag(:div, style: 'margin-bottom: 30px') {
                      if can_modify
                        link_to_remote(
                          'Allow translators to apply',
                          { action: :update_language_status, status: RESOURCE_LANGUAGE_OPEN, resource_language_id: resource_language.id },
                          class: 'rounded_but_orange', method: :post
                        )
                      end
                    }
                  end

                  concat search_for_translators(text_resource.language, resource_language.language)

                elsif user[:type] == 'Translator'
                  translator_chat = text_resource.resource_chats.where('(resource_chats.translator_id=?) AND (resource_chats.resource_language_id=?)', user.id, resource_language.id).first
                  if translator_chat
                    concat link_to('Communicate with client', controller: :resource_chats, action: :show, text_resource_id: text_resource.id, id: translator_chat.id)
                  elsif (resource_language.managed_work.translator != @user) && user.can_apply_to_resource_translation(resource_language)
                    concat link_to('Apply for this work', controller: :resource_chats, action: :new, text_resource_id: text_resource.id, resource_lang_id: resource_language.id)
                  end
                end
              end
            end

            reviewer = content_tag(:div) do
              concat managed_work_controls(user, resource_language, review_cost)
              if resource_language.review_enabled? && !resource_language.managed_work.translator && (@user[:type] == 'Translator') && resource_language.managed_work.translator_can_apply_to_review(@user)
                concat content_tag(:div, style: 'margin-bottom: 10px') {
                  link_to_remote(
                    'Become the reviewer for this job',
                    { controller: :managed_works, action: :be_reviewer, id: resource_language.managed_work.id },
                    'data-confirm' => 'Are you sure? You will need to review the translation as soon as it completes. Remember that if you become the reviewer, you cannot translate this project.',
                    class: 'rounded_but_orange', method: :post
                  )
                }
              end
            end

            completed = stats[resource_language.language_id][TextResource::STRING_TRANSLATED]
            missing = stats[resource_language.language_id][TextResource::STRING_UNTRANSLATED]
            reviewed = stats[resource_language.language_id][TextResource::STRING_REVIEWED]
            total_strings = completed + missing
            concat content_tag(:tr, id: "resource_language_#{resource_language.id}") {
              concat content_tag(:td) {
                concat content_tag(:p, content_tag(:strong, resource_language.language.name))
                unless resource_language.feedbacks.empty?
                  concat content_tag(:p, link_to('User feedback (%d)' % resource_language.feedbacks.length, controller: :feedbacks, action: :list, ot: 'RL', oi: resource_language.id))
                end
              }
              if reviewer && (reviewer != '')
                concat content_tag(:td) {
                  concat ''.html_safe; concat translator; concat '<br /><hr /><br />'.html_safe; concat reviewer
                }
              else
                concat content_tag(:td, translator)
              end

              if total_strings > 0
                translation_status_class = status_class(completed, total_strings)
                review_status_class = status_class(reviewed, total_strings)
                concat content_tag(:td, class: 'translation_status') {
                  concat content_tag(:p) {
                    concat ''.html_safe; concat completed; concat ' of '.html_safe; concat total_strings; concat ' strings translated '.html_safe; concat content_tag(:span, "(#{(completed * 100.0 / total_strings).to_i}%)", class: translation_status_class)
                  }
                  if resource_language.review_enabled?
                    concat content_tag(:p) {
                      concat ''.html_safe; concat reviewed; concat ' of '.html_safe; concat total_strings; concat ' strings reviewed '.html_safe; concat content_tag(:span, "(#{(reviewed * 100.0 / total_strings).to_i})%", class: review_status_class)
                    }
                  end
                  concat content_tag(:p, class: 'comment') {
                    concat 'Updated '.html_safe; concat disp_time(resource_language.updated_at).html_safe
                  }
                }
              else
                concat content_tag(:td, 'No strings yet')
              end
              if @user.has_client_privileges?
                concat content_tag(:td) {
                  content_tag(:div, id: "output_filename#{resource_language.id}") do
                    render(partial: 'output_filename', object: resource_language)
                  end
                }
              end
              concat content_tag(:td, status, class: 'resource_language_actions') if is_client || is_supporter
            }
          end
        }

        if is_client && can_modify
          concat '<br />'.html_safe
          concat content_tag(:p, style: 'text-align: right') {
            concat link_to 'Select all languages', 'javascript:void(0)', onclick: 'toggleAllTickbox()', style: 'margin-right: 20px', class: 'tickToggler', data: { status: 0 }
            concat text_field_tag(:begin_translations, 'Begin marked translations', disabled: 'disabled', onclick: "confirm_send_translations('Are you sure you want to begin the marked translation jobs?', 'selected_chats[]', #{text_resource.id})", type: 'button', class: 'submit_chat')
          }
        end

        subtotal = total_cost
        current_balance = money_account ? money_account.balance.ceil_money : 0
        net_total = subtotal - current_balance
        if is_client && user.has_to_pay_taxes?
          tax_amount = user.calculate_tax subtotal
          net_total += tax_amount
        end

        if is_client && net_total.to_s.to_f > 0
          finance_page_link = link_to 'finance page', '/finance'
          missing_fund_message = content_tag(:div, id: 'missing_funds', style: 'margin: 2em 4em 2em 4em; padding: 1em; border: 2pt solid #FF0000') do
            concat content_tag(:h3, 'Missing Funding')
            concat content_tag(:p, pre_format("Your account doesn't have enough balance in order to translate to all languages. If you are not planning to translate to all languages now you can ignore this message and start the work using the table below for the languages you have enough funds. Or to deposit the exact amount needed for all languages and start the work in this project, please click on \"Pay with PayPal\" button. If you want to deposit some other amount, go to your #{finance_page_link} instead.", true))
            concat form_tag({ action: :deposit_payment }, autocomplete: 'off') {
              concat render partial: 'shared/vat_request', locals: { show_subtotal_in_non_eu: true }
              concat content_tag(:div, id: 'total_box') {
                concat content_tag(:table, cellspacing: 0, cellpadding: 3, class: 'stats', width: '100%') {
                  concat content_tag(:tr, class: 'headerrow') {
                    %w(Description Cost).each { |th| concat content_tag(:th, th) }
                  }
                  total_missing = 0
                  missing_funds.each do |missing|
                    amount_check_box = if missing_funds.size > 1
                                         check_box_tag("resource_language#{missing[0].id}", 1, 1, onclick: 'fix_total_amount(this)')
                                       else
                                         hidden_field_tag("resource_language#{missing[0].id}", 1)
                                       end
                    concat content_tag(:tr, class: 'item') {
                      concat content_tag(:td) {
                        concat ''.html_safe; concat amount_check_box; concat ' Deposit payment for '; concat content_tag(:b, missing[1])
                      }
                      concat content_tag(:td) {
                        concat content_tag(:span, missing[2].ceil_money.to_s + ' USD', class: 'amount')
                        concat hidden_field_tag("transaction_code#{missing[0].id}", missing[3])
                      }
                    }

                    total_missing += missing[2]
                  end

                  # subtotal
                  concat content_tag(:tr, class: 'subtotal software-translation') {
                    concat content_tag(:th, 'Subtotal')
                    concat content_tag(:th) {
                      concat content_tag(:b) {
                        concat content_tag(:span, subtotal, class: 'amount')
                        concat ' USD'.html_safe
                      }
                    }
                  }

                  # Currently in your account
                  concat content_tag(:tr, class: 'current_in_account') {
                    concat content_tag(:td, 'Account Balance')
                    concat content_tag(:td) {
                      concat content_tag(:span, current_balance, class: 'amount')
                      concat ' USD'.html_safe
                    }
                  }
                  hide_row = user.has_to_pay_taxes? ? '' : 'display:none'

                  # TAX
                  concat content_tag(:tr, class: 'tax_details', style: hide_row) {
                    concat content_tag(:td) {
                      concat 'VAT Tax in '.html_safe
                      concat content_tag(:span, user.country.try(:name), class: 'country_name')
                      concat ' ('.html_safe
                      concat content_tag(:span, user.tax_rate.to_i, class: 'tax_rate')
                      concat ') '.html_safe
                    }
                    concat content_tag(:td) {
                      concat content_tag(:span, tax_amount, class: 'amount')
                      concat ' USD'.html_safe
                    }
                  }
                  concat content_tag(:tr) {
                    concat content_tag(:th, content_tag(:b, 'Total'))
                    concat content_tag(:th) {
                      concat content_tag(:b, net_total, id: 'total_cost')
                      concat content_tag(:b, ' USD')
                    }
                  }
                }
                concat '<br />'.html_safe
              }
              if @user.can_deposit?
                concat submit_tag('Pay with PayPal', style: 'padding: 0.5em 1em;', id: 'pay', data: { disable_with: 'Pay with PayPal' })
                concat '<br />'.html_safe
                concat image_tag('paypal_payments.png', style: 'margin: 5px', width: 242, height: 31, alt: 'PayPal payment options')
                concat '<br />'.html_safe
                concat content_tag(:p, 'You don\'t need to have a PayPal account. PayPal allows you to pay with a credit card as well.', class: 'comment')
                concat content_tag(:h4, 'Other payment options')
                concat content_tag(:p) {
                  concat 'Don\'t like PayPal? Have a look at '.html_safe
                  concat link_to('other payment methods', controller: :finance, action: :payment_methods)
                  concat '.'.html_safe
                }
              end
            }
          end

          concat missing_fund_message
        end
      else
        concat content_tag(:p, 'No translation languages selected yet. Source language have to be choosen first.', class: 'warning')
      end
    end
  end

  def format_selector(resource_formats)
    content_tag(:table, class: 'stats', style: 'margin: 1em; font-size: 0.9em;') do
      concat content_tag(:tr, class: 'headerrow') {
        concat content_tag(:th, 'Type')
        concat content_tag(:th, 'Example')
        concat content_tag(:th, 'Character encoding')
      }
      resource_formats.each do |rf|
        concat content_tag(:tr, id: "format#{rf.id}") {
          concat content_tag(:td, rf.description)
          concat content_tag(:td, rf.example.gsub("\n", '<br />').html_safe)
          concat content_tag(:td, ResourceFormat::ENCODING_NAMES[rf.encoding])
        }
      end
    end
  end

  def upload_operations(resource_upload)
    content_tag(:div) do
      unless @text_resource.resource_languages.empty?
        form_tag(controller: :text_resources, action: :create_translations, id: @text_resource.id, resource_upload_id: resource_upload.id) do
          if resource_upload.resource_upload_format.resource_format.name != 'PO'
            concat content_tag(:h4, 'Format for translation')
            concat content_tag(:p) {
              concat content_tag(:label, title: 'You will receive a resource file with the exact format and structure as the original but with translated contents') {
                radio_button_tag(:create_po, 0, true, id: "createx1#{resource_upload.id}") + ' Original format'.html_safe
              }
              concat '<br />'.html_safe
              concat content_tag(:label, title: 'You will receive a .po file translating the original strings') {
                radio_button_tag(:create_po, 1, false, id: "createx2#{resource_upload.id}") + '.po file'.html_safe
              }
            }
          end
          if resource_upload.resource_upload_format.resource_format.name.index('iPhone')
            concat content_tag(:p) {
              concat content_tag(:label) {
                check_box_tag(:include_affiliate, 1, resource_upload.resource_upload_format.include_affiliate == 1, id: 'include_affiliate%d' % resource_upload.id) + ' Include translation credit text and affiliate link'.html_safe
              }
              if resource_upload.resource_upload_format.include_affiliate == 1
                lang_name = @text_resource.language.name
                if (lang_name != 'English') && ICL_CREDIT_FOOTER.key?(lang_name)
                  credit_text = ICL_CREDIT_FOOTER[lang_name]
                end
                concat ' | '.html_safe
                concat link_to('Credit link instructions', '#', onclick: "jQuery('#affiliate_integration#{resource_upload.id}').slideDown(300)")
              else
                concat ' | '.html_safe
                concat link_to('Learn more &raquo;'.html_safe, 'http://docs.icanlocalize.com/?page_id=1100', target: '_blank')
              end
              concat content_tag(:p) {
                concat '<i style="font-size:12px;">In case of issues using the translation files in your software, enable the BOM function <br>at the bottom of this page, then update and download again the translations.</i>'.html_safe
              }
            }
            if resource_upload.resource_upload_format.include_affiliate == 1
              credit_text = 'Translated by ICanLocalize'
              concat content_tag(:div, id: "affiliate_integration#{resource_upload.id}", style: 'margin: 1em; padding: 1em; background-color: #F0F0F0; border: 1pt solid #808080; display: none;') {
                concat content_tag(:p, 'We have added the following strings to your translated resource files:')
                concat content_tag(:textarea, rows: 2, cols: 50, style: 'width:100%;') {
                  concat '"ICL_translation_credit"="'.html_safe + credit_text + '";\n'.html_safe
                  concat '"ICL_affiliate_URL"="http://www.icanlocalize.com/my/invite/' + @text_resource.client.id.to_s + '";'.html_safe
                }
                concat content_tag(:p) {
                  content_tag(:span, 'Note: the text itself is translated in the resource files.', class: 'comment')
                }
                concat content_tag(:p, "You need to add this text to the original resource file too (in #{@text_resource.language.name}).")
                concat content_tag(:p) {
                  concat 'To include this credit message with the affiliate link in your application, have a look at the '.html_safe
                  concat link_to('integration instructions &raquo;'.html_safe, 'http://docs.icanlocalize.com/?page_id=1100', target: '_blank')
                }
                concat content_tag(:p, content_tag(:strong, 'Every new client that comes to ICanLocalize from this link will be associated with your account and will generate affiliate commission for you.'))
              }
            end
          end
          if resource_upload.resource_downloads.empty?
            concat submit_tag('Create translations', disable_with: 'Processing...', data: { disable_with: 'Processing...' })
            pcontent = content_tag(:p) do
              concat 'Click on the '.html_safe
              concat content_tag(:i, 'Create translations')
              concat ' button to create the translated resource file(s) with the current translations, then click on "Download All" link to get your translations.'.html_safe
            end
          else
            concat submit_tag('Update translations', disable_with: 'Processing...', data: { disable_with: 'Processing...' })
            pcontent = content_tag(:div) do
              concat content_tag(:p) {
                concat 'Click on the '.html_safe
                concat content_tag(:i, 'Update translations')
                concat ' button to regenerate the translated resource file(s) with the current translations, then click on "Download All" link to get your translations. '.html_safe
              }
              concat content_tag(:p, 'The translator\'s work doesn\'t automatically update the translated resource file(s).')
            end
          end
          concat tooltip(pcontent)
        end
      else
        'You will be able to translate this resource file once you add translation languages.'
      end
    end
  end

  def resource_strings_table(resource_strings)
    content_tag(:div) do
      concat content_tag(:table, cellspacing: 0, cellpadding: 3, style: 'width:100%; margin: 0 1px 0 1px;') {
        content_tag(:tr) do
          concat content_tag(:th, 'Label', style: 'width: 200px;')
          concat content_tag(:th, 'String to translate')
        end
      }
      concat content_tag(:div, style: 'max-height: 400px; overflow:scroll; padding: 1px;') {
        content_tag(:table, cellspacing: 0, cellpadding: 3, class: 'stats', style: 'width:100%') do
          resource_strings.each do |resource_string|
            concat content_tag(:tr) {
              concat content_tag(:td, resource_string[:token], class: 'comment')
              concat content_tag(:td, resource_string[:text])
            }
          end
        end
      }
    end
  end

  def list_downloads_for_upload(resource_upload)
    content_tag(:div) do
      decode_dict = [ENCODING_UTF16_LE, ENCODING_UTF16_BE].include?(resource_upload.resource_upload_format.resource_format.encoding) ? { decode: 1 } : {}
      unless resource_upload.resource_downloads.empty?
        concat content_tag(:ul, class: 'resource_downloads') {
          resource_upload.resource_downloads.each do |resource_download|
            concat content_tag(:li) {
              concat link_to({ controller: :resource_downloads, action: :show, text_resource_id: resource_download.text_resource.id, id: resource_download.id }.merge(decode_dict)) {
                image_tag('icons/view.png', border: 0, width: 16, height: 16, alt: 'view', title: 'view')
              }
              concat '&nbsp;'.html_safe
              concat link_to(controller: :resource_downloads, action: :download, text_resource_id: resource_download.text_resource.id, id: resource_download.id) {
                image_tag('icons/download.png', border: 0, width: 16, height: 16, alt: 'download', title: 'download')
              }
              fname_idx = resource_download.orig_filename.split('.').first.size
              mo_fname = File.dirname(resource_download.full_filename) + '/' + resource_download.orig_filename[0...fname_idx] + '.mo'
              if File.exist?(mo_fname) # looking for mo file
                concat '&nbsp;'.html_safe
                concat link_to(File.basename(mo_fname), { controller: :resource_downloads, action: :download_mo, text_resource_id: resource_download.text_resource.id, id: resource_download.id }, title: disp_time(resource_download.chgtime)) + ' | '.html_safe
              end
              concat '&nbsp;'.html_safe
              concat link_to(resource_download.orig_filename, { controller: :resource_downloads, action: :show, text_resource_id: resource_download.text_resource.id, id: resource_download.id }.merge(decode_dict), title: disp_time(resource_download.chgtime))
              concat '&nbsp;'.html_safe
              concat ' ('.html_safe
              concat resource_download.upload_translation.language.name
              if resource_download.resource_download_stat&.total && (resource_download.resource_download_stat.total > 0)
                concat ' - '.html_safe
                concat((100.0 * resource_download.resource_download_stat.completed.to_f / resource_download.resource_download_stat.total.to_f).round.to_s + '%'.html_safe)
              end
              concat ') '
            }
          end
        }
        if File.exist?(resource_upload.all_translations_fname)
          concat '<br />'.html_safe
          concat content_tag(:p) {
            concat link_to(controller: :resource_uploads, action: :download_translations, text_resource_id: resource_upload.text_resource.id, id: resource_upload.id) {
              concat image_tag('icons/drawer.png', border: 0, width: 16, height: 16, alt: 'download all', title: 'download all')
              concat ' Download all'.html_safe
            }
          }
        end
      end
    end
  end

  def public_list_downloads_for_upload(resource_upload)
    decode_dict = [ENCODING_UTF16_LE, ENCODING_UTF16_BE].include?(resource_upload.resource_upload_format.resource_format.encoding) ? { decode: 1 } : {}
    look_for_mo = resource_upload.resource_upload_format.resource_format.name == 'PO'

    if !resource_upload.resource_downloads.empty?
      res = infotab_header(['Language', 'PO file (for editing)', 'MO file (for the CMS)', 'Completed'])
      resource_upload.resource_downloads.each do |resource_download|
        res << '<tr><td>' + resource_download.upload_translation.language.name + '</td>'
        res << '<td>' + link_to(h(resource_download.orig_filename), controller: :resource_downloads, action: :download, text_resource_id: resource_download.text_resource.id, id: resource_download.id) + '</td>'
        res << '<td>'
        if look_for_mo
          fname_idx = resource_download.orig_filename.rindex('.')
          mo_fname = File.dirname(resource_download.full_filename) + '/' + resource_download.orig_filename[0...fname_idx] + '.mo'
          if File.exist?(mo_fname)
            res += link_to(h(File.basename(mo_fname)), { controller: :resource_downloads, action: :download_mo, text_resource_id: resource_download.text_resource.id, id: resource_download.id }, title: disp_time(resource_download.chgtime))
          end
        end
        res << '</td><td>'
        if resource_download.resource_download_stat
          res += (100 * resource_download.resource_download_stat.completed / resource_download.resource_download_stat.total).to_s + '%'
        end
        res << '</td></tr>'
      end
      res << '</table>'
      return res
    else
      return '<p>Translations are not available yet</p>'
    end
  end

  def project_progress(text_resource)
    have_languages = text_resource.resource_languages.count > 0
    have_uploads = text_resource.resource_strings.count > 0
    missing_translators = false
    can_choose_translators = false
    translation_pending = false
    text_resource.resource_languages.each do |rl|
      unless rl.selected_chat
        missing_translators = true
        if rl.resource_chats.where('resource_chats.status=?', RESOURCE_CHAT_APPLIED).first
          can_choose_translators = true
        end
      end
      wc = text_resource.count_words(text_resource.untranslated_strings(rl.language), @text_resource.language, rl, false, "untranslated to #{rl.language.name}")
      translation_pending = true if wc > 0
    end
    content_tag(:ol) do
      concat phase_item('Create project', true, true)
      concat phase_item('Select <a href="#languages">translation languages</a>', true, have_languages)
      concat phase_item('Upload <a href="#upload_new">resource files to translate</a>', true, have_uploads)
      concat phase_item('Translators apply for the job', have_languages && have_uploads, !(missing_translators && !can_choose_translators))
      concat phase_item('<a href="#languages">Select your translators</a>', (have_languages && have_uploads && can_choose_translators) || !missing_translators, !missing_translators)
      concat phase_item('<a href="#languages">Begin translation</a>', have_languages && have_uploads && !missing_translators, !translation_pending)
      concat phase_item("When ready, download the #{link_to_if(have_languages && have_uploads && !missing_translators && !translation_pending, 'completed translations', '#uploads')}", have_languages && have_uploads && !missing_translators && !translation_pending, true)
    end
  end

  def phase_item(txt, enabled, completed)
    content_tag(:li) do
      style = !enabled ? 'color: #808080;' : (!completed ? 'font-weight: bold;' : '')
      concat content_tag(:span, txt.html_safe, style: style)
      if enabled
        icon = 'icons/'
        icon += completed ? 'selectedtick_16.png' : 'important_16.png'
        concat '&nbsp; '.html_safe
        concat image_tag(icon, width: 16, height: 16, alt: 'status', style: 'vertical-align: bottom')
      end
    end
  end

  def translation_summary(text_resource, languages, simple_cell, sort = true, page = 1, per = 20)
    resource_strings = text_resource.resource_strings.joins(:string_translations).includes(:string_translations).distinct.page(page).per(per)
    language_ids = languages.collect(&:id)

    content_tag(:div) do
      resource_strings.sort_by { |e| e[:txt] } if sort
      concat content_tag(:div, paginate(resource_strings), class: 'pager_control')
      concat content_tag(:table, style: 'width: 100%', class: 'stats') {
        concat content_tag(:tr) {
          concat content_tag(:th, 'Label') unless simple_cell
          concat content_tag(:th, text_resource.language.name)
          concat content_tag(:th, 'Description')
          languages.collect(&:name).each { |th| concat content_tag(:th, th) }
        }
        resource_strings.each do |resource_string|
          concat content_tag(:tr) {
            concat content_tag(:td, h(resource_string.token)) unless simple_cell
            concat content_tag(:td, h(resource_string.txt))
            concat content_tag(:td, h(resource_string.comment))
            translations = {}
            resource_string.string_translations.each { |st| translations[st.language_id] = st.txt }
            language_ids.each do |language_id|
              concat content_tag(:td, (simple_cell ? h(translations[language_id] || '') : text_area_tag("translation_string_#{resource_string.id}_#{language_id}", h(translations[language_id] || ''), col: 30, rows: 3, style: 'width: 100%')))
            end
          }
        end
      }
      concat '<br />'.html_safe
      concat content_tag(:p, (_('Produced on %s') % disp_time(Time.now)))
    end
  end

  def chats_for_resource_languages(resource_languages)
    res = []
    resource_languages.each do |rl|
      if rl.selected_chat
        res << link_to('Chat between client and %s translator' % rl.language.name, controller: :resource_chats, action: :show, id: rl.selected_chat.id, text_resource_id: rl.text_resource.id)
      end
    end
    res.join(', ')
  end

  def show_translation_candidates(candidates, languages)
    form_tag({ action: :apply_from_other_projects }, id: :strings_list) do
      concat content_tag(:table, style: 'width: 100%', class: 'stats') {
        concat content_tag(:tr) {
          (['String'] + languages.collect(&:name)).each do |lang|
            concat content_tag(:th, lang)
          end
        }
        idx = 0
        candidates.each do |resource_string, translations|
          concat content_tag(:tr) {
            concat content_tag(:td) {
              if resource_string.comment.blank?
                concat content_tag(:span, h(resource_string.txt))
              else
                concat content_tag(:abbr, h(resource_string.txt), title: h(resource_string.comment))
              end
              languages.each do |language|
                concat content_tag(:td) {
                  if translations.key?(language)
                    translation = translations[language]
                    txt = content_tag(:span) do
                      concat content_tag(:abbr, translation.txt, title: translation.resource_string.text_resource.name + (!translation.resource_string.comment.blank? ? (': ' + translation.resource_string.comment) : ''))
                    end
                    idx += 1
                    concat content_tag(:label) {
                      concat check_box_tag("change_#{resource_string.id}_#{language.id}", 1, 1)
                      concat ' '.html_safe
                      concat txt
                    }
                    concat hidden_field_tag("xlat_#{resource_string.id}_#{language.id}", translation.txt)
                    concat hidden_field_tag("str_#{idx}", "#{resource_string.id}_#{language.id}")
                  else
                    ' '.html_safe
                  end
                }
              end
            }
          }
        end
        concat content_tag(:div, class: 'tabbottom') {
          concat link_to 'Toggle selection', '#', onclick: "toggleCheckBoxes('strings_list'); return false"
        }
        concat hidden_field_tag('max_idx', idx)
        concat '<br />'.html_safe
        concat content_tag(:p) {
          concat submit_tag('Update selected translations', style: 'padding:3px 6px;', data: { disable_with: 'Processing...' }); concat ' | '.html_safe; concat link_to('cancel', action: :show)
        }
      }
    end
  end

  # def show_translation_candidates(candidates, languages)
  #   res = []
  #   res << form_tag({ action: :apply_from_other_projects }, id: :strings_list)
  #   res << infotab_header(['String'] + languages.collect(&:name))
  #   idx = 0
  #   candidates.each do |resource_string, translations|
  #     res << '<tr><td>%s</td>' % (resource_string.comment.blank? ? h(resource_string.txt) : '<abbr title="%s">%s</abbr>' % [h(resource_string.comment), h(resource_string.txt)])
  #     languages.each do |language|
  #       res << '<td>'
  #       if translations.key?(language)
  #         translation = translations[language]
  #         txt = '<abbr title="%s">%s</abbr>' % [translation.resource_string.text_resource.name + (!translation.resource_string.comment.blank? ? (': ' + translation.resource_string.comment) : ''), translation.txt]
  #         idx += 1
  #         res << '<label>' + check_box_tag("change_#{resource_string.id}_#{language.id}", 1, 1) + ' ' + txt + '</label>'
  #         res << hidden_field_tag("xlat_#{resource_string.id}_#{language.id}", translation.txt)
  #         res << hidden_field_tag("str_#{idx}", "#{resource_string.id}_#{language.id}")
  #       else
  #         res << '&nbsp;'
  #       end
  #       res << '</td>'
  #     end
  #     res << '</tr>'
  #   end
  #   res << '</table>'
  #   res << '<div class="tabbottom">'
  #   res << "<a href=\"#\" onclick=\"toggleCheckBoxes('strings_list'); return false;\">Toggle selection</a>"
  #   res << '</div>'
  #   res << hidden_field_tag('max_idx', idx)
  #   res << '<br /><p>'
  #   res << submit_tag('Update selected translations', style: 'padding:3px 6px;', data: { disable_with: 'Processing...' }) + ' | ' + link_to('cancel', action: :show) + '</p></form>'
  #   res.join.html_safe
  # end

  def resource_account_form(resource_account)
    content_tag(:div) do
      if @editing_resource_account
        concat form_tag({ action: :edit_resource_account, resource_account_id: resource_account.id }, remote: true) {
          concat 'Balance: '.html_safe
          concat text_field_tag(:balance, resource_account.balance, size: 10)
          concat ' USD.'.html_safe
          concat submit_tag('Save', id: "edit#{resource_account.id}")
        }
        concat ' '.html_safe
        concat form_tag({ action: :edit_resource_account, resource_account_id: resource_account.id, req: 'hide' }, remote: true) {
          submit_tag('Cancel', id: "edit#{resource_account.id}", data: { disable_with: 'Cancel' })
        }

      else
        concat content_tag(:p, 'Credit for translation in this language: %0.2f USD.' % resource_account.balance)

        if @user.has_supporter_privileges?
          concat form_tag({ action: :edit_resource_account, resource_account_id: resource_account.id, req: 'show' }, remote: true) {
            submit_tag('Edit', id: "edit#{resource_account.id}", data: { disable_with: 'Edit' })
          }
          concat ' '.html_safe
          concat link_to('Money Account', controller: :finance, action: :account_history, id: resource_account.id)
        end
      end
    end
  end

  def purge_action(text_resource)
    content_tag(:span) do
      if text_resource.purge_step.nil?
        concat button_to('Delete unused strings', { action: 'reset_string_contexts' }, 'data-confirm' => 'Are you sure you want to delete contexts of all strings in the project?')
      elsif text_resource.purge_step == TEXT_RESOURCE_PURGE_CHOOSE_FILES
        concat 'Choose '.html_safe
        concat link_to('uploaded resource files', '#uploads')
        concat '<br />'.html_safe
        concat button_to('Cancel delete unused', { action: 'abort_purge_strings' }, 'data-confirm' => 'Are you sure you want cancel?')
      elsif text_resource.purge_step == TEXT_RESOURCE_PURGE_FILES_CHOSEN
        orphan_count = @text_resource.resource_strings.joins(:string_translations).where('(context IS NULL) AND  (string_translations.status != ?)', STRING_TRANSLATION_BEING_TRANSLATED).count
        concat button_to('Delete %d orphan strings' % orphan_count, { action: 'delete_strings_with_no_context' }, 'data-confirm' => 'Are you sure you want to delete all these strings? Translations will be permanently deleted. There is no undo.')
        concat '<br />'.html_safe
        concat content_tag(:span, class: 'comment') do
          concat 'You can choose more '.html_safe
          concat link_to('uploaded resource files', '#uploads')
        end
        concat '<br />'.html_safe
        concat button_to('Cancel delete unused', { action: 'abort_purge_strings' }, 'data-confirm' => 'Are you sure you want cancel?')
      end
    end
  end

  def purge_message(text_resource)
    if text_resource.purge_step.nil?
      'Delete strings that are no longer found in any resource file. Step one - reset contexts of all strings.'
    elsif text_resource.purge_step == TEXT_RESOURCE_PURGE_CHOOSE_FILES
      'Click on the button to "Keep strings in this file" next to the resource files that you want to keep in the strings database.'
    elsif text_resource.purge_step == TEXT_RESOURCE_PURGE_FILES_CHOSEN
      'After you clicked on "Keep strings" for all the files you want, use this button to delete all the remaining strings.'
    end
  end

  def status_class(completed, total)
    if completed == 0
      'status-red'
    elsif completed == total
      'status-green'
    else
      'status-yellow'
    end
  end
end
