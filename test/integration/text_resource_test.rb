require "#{File.dirname(__FILE__)}/../test_helper"

class TextResourceTest < ActionDispatch::IntegrationTest
  fixtures :users, :translator_languages, :money_accounts, :languages, :currencies, :identity_verifications, :translator_languages, :available_languages, :resource_formats

  def test_translate
    init_email_deliveries
    delete_all

    checker = PeriodicChecker.new(Time.now)
    cnt = checker.per_profile_mailer
    assert_equal 0, cnt
    check_emails_delivered(0)

    client = users(:amir)

    session = login(client)

    get(url_for(controller: :text_resources, action: :index))
    assert_response :success

    get(url_for(controller: :text_resources, action: :new))
    assert_response :success

    # --- create the project ---
    language = languages(:English)
    name = 'Test proj'
    description = 'this is what it is about'

    text_resource_count = TextResource.count

    post(url_for(controller: :text_resources, action: :create),
         params: { text_resource: { name: name, description: description, language_id: language.id } })
    assert_response :redirect

    assert_equal text_resource_count + 1, TextResource.count

    text_resource = TextResource.all.to_a[-1]
    assert_equal text_resource.name, name
    assert_equal text_resource.description, description

    assert_equal text_resource.language, language
    required_text = text_resource.required_text

    # --- view the project ---
    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    # --- edit the project's name and description ---
    get(url_for(controller: :text_resources, action: :edit_description, id: text_resource.id))
    assert_response :success

    put(url_for(controller: :text_resources, action: :update, id: text_resource.id, _method: 'PUT'),
        text_resource: { name: name + 'x', description: description + 'xx', required_text: required_text.to_s })
    assert_response :redirect

    text_resource.reload
    assert_equal name + 'x', text_resource.name
    assert_equal description + 'xx', text_resource.description

    # --- choose translation languages ---
    xml_http_request(:post, url_for(controller: :text_resources, action: :edit_languages, id: text_resource.id, format: :js), req: 'show')
    assert_response :success

    assert assigns(:show_edit_languages)
    assert assigns(:languages)

    languages = assigns(:languages)
    assert languages.length >= 2, 'not enough translation languages'

    to_language_dic = {}
    to_languages = [languages(:Spanish), languages(:German)]
    to_languages.each do |tl|
      assert languages.key?(tl.name)
      to_language_dic[tl.id] = 1
    end

    post(url_for(controller: :text_resources, action: :edit_languages, id: text_resource.id, format: :js),
         req: 'save', language: to_language_dic)
    assert_response :redirect

    text_resource.reload
    assert_equal to_languages.length, text_resource.resource_languages.length

    to_languages.each do |tl|
      assert text_resource.resource_languages.where('language_id=?', tl.id).first
    end

    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    # --- disable the review ---
    text_resource.resource_languages.each do |rl|
      assert rl.managed_work
      managed_work = rl.managed_work
      assert_equal MANAGED_WORK_ACTIVE, managed_work.active

      post(url_for(controller: :managed_works, action: :update_status, id: managed_work.id, active: MANAGED_WORK_INACTIVE, format: :js))
      assert_response :success

      managed_work.reload
      assert_equal MANAGED_WORK_INACTIVE, managed_work.active
    end

    resource_format = ResourceFormat.where('name=?', 'Delphi').first
    assert resource_format

    # --- translators are still not notified (no strings uploaded) ---
    cnt = checker.per_profile_mailer
    assert_equal 0, cnt
    check_emails_delivered(cnt)

    # --- upload the project ---

    resource_upload_count = ResourceUpload.count

    fdata = fixture_file_upload('char_conversion/delphi_very_short.txt', 'application/octet-stream')
    multipart_post(url_for(controller: :resource_uploads, action: :create, text_resource_id: text_resource.id),
                   resource_upload: { uploaded_data: fdata }, resource_format_id: resource_format.id)
    assert_nil flash[:problem]
    assert_response :success

    assert_equal resource_upload_count + 1, ResourceUpload.count

    resource_upload = ResourceUpload.all.to_a[-1]
    assert_nil resource_upload.normal_user

    resource_strings = assigns(:resource_strings)
    assert resource_strings
    assert_equal 3, resource_strings.length

    # cancel this upload
    delete(url_for(controller: :resource_uploads, action: :destroy, text_resource_id: text_resource.id, id: resource_upload.id))
    assert_response :redirect

    assert_equal resource_upload_count, ResourceUpload.count
    assert_equal 0, text_resource.resource_strings.length

    # upload again, now accept
    fdata = fixture_file_upload('char_conversion/delphi_very_short.txt', 'application/octet-stream')
    multipart_post(url_for(controller: :resource_uploads, action: :create, text_resource_id: text_resource.id),
                   resource_upload: { uploaded_data: fdata }, resource_format_id: resource_format.id)
    assert_response :success

    resource_strings = assigns(:resource_strings)
    assert resource_strings
    assert_equal 3, resource_strings.length

    assert_equal resource_upload_count + 1, ResourceUpload.count

    resource_upload = ResourceUpload.all.to_a[-1]
    assert_nil resource_upload.normal_user

    post(url_for(controller: :resource_uploads, action: :scan_resource, text_resource_id: text_resource.id, id: resource_upload.id), string_idx_param(resource_strings))
    assert_response :redirect

    text_resource.reload

    assert_equal 3, text_resource.resource_strings.length

    # --- see that translators are notified now ---
    prev_sent_notification_count = SentNotification.count

    cnt = checker.per_profile_mailer
    assert_not_equal 0, cnt
    check_emails_delivered(cnt)

    assert_equal prev_sent_notification_count + cnt * text_resource.resource_languages.count, SentNotification.count

    # second time, no notification (already notified)
    cnt = checker.per_profile_mailer
    assert_equal 0, cnt
    check_emails_delivered(cnt)

    # check that we can view the uploaded data
    get(url_for(controller: :resource_uploads, action: :show, text_resource_id: text_resource.id, id: resource_upload.id))
    assert_response :success
    assert_equal resource_upload, assigns(:resource_upload)

    # --- do a sample translation by the client ---
    get(url_for(controller: :resource_strings, action: :index, text_resource_id: text_resource.id, set_args: 1))
    assert_response :success
    languages = assigns(:languages)
    assert_equal to_languages.length, languages.length
    assert_equal text_resource.resource_strings.length, resource_strings.length

    # go to the middle string (has one before and after)
    resource_string = text_resource.resource_strings[1]
    get(url_for(controller: :resource_strings, action: :show, text_resource_id: text_resource.id, id: resource_string.id))
    assert_response :success

    languages = assigns(:languages)
    assert_equal to_languages.length, languages.length
    assert_equal text_resource.resource_strings.length, resource_strings.length

    translations = assigns(:translations)
    assert translations
    assert_equal languages.length, translations.length

    assert assigns(:prev_str)
    assert assigns(:next_str)

    resource_string = assigns(:resource_string)
    assert resource_string

    assert resource_string.user_can_edit_original(client)
    to_languages.each { |l| assert resource_string.user_can_edit_translation(client, l) }

    # --- edit the original ---
    xml_http_request(:get, url_for(controller: :resource_strings, action: :edit, text_resource_id: text_resource.id, id: resource_string.id))
    assert_response :success

    assert assigns(:editing_original)

    updated_txt = 'modified original text'
    xml_http_request(:put, url_for(controller: :resource_strings, action: :update, text_resource_id: text_resource.id, id: resource_string.id),
                     resource_string: { txt: updated_txt }, req: 'save')
    assert_response :success

    resource_string.reload

    assert_equal updated_txt, resource_string.txt

    untranslated_strings = text_resource.untranslated_strings(to_languages[0])
    assert_equal 3, untranslated_strings.length
    assert_equal 6, text_resource.count_words(untranslated_strings, text_resource.language, nil, false, 'test-all')

    # --- edit the translations ---
    to_languages.each do |tl|

      resource_language = text_resource.resource_languages.where('language_id=?', tl.id).first
      assert resource_language

      assert resource_string.string_translations.where('language_id=?', tl.id).first

      text_resource.reload
      prev_resource_language_version_num = resource_language.version_num

      xml_http_request(:post, url_for(controller: :resource_strings, action: :edit_translation, text_resource_id: text_resource.id, id: resource_string.id, lang_id: tl.id))
      assert_response :success

      assert assigns(:editing)
      assert_equal prev_resource_language_version_num, resource_language.version_num

      updated_translation = "updated translation to #{tl.name}"
      xml_http_request(:post, url_for(controller: :resource_strings, action: :update_translation, text_resource_id: text_resource.id, id: resource_string.id, lang_id: tl.id),
                       string_translation: { txt: updated_translation }, complete_translation: 1, req: 'save')
      assert_response :success

      resource_language.reload
      assert_equal prev_resource_language_version_num + 1, resource_language.version_num, "before: #{prev_resource_language_version_num}, now: #{resource_language.version_num}"

      resource_string.reload

      string_translation = resource_string.string_translations.where('language_id=?', tl.id).first
      assert string_translation

      assert_equal STRING_TRANSLATION_COMPLETE, string_translation.status
      assert_equal updated_translation, string_translation.txt

    end

    # --- view the project ---
    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    untranslated_strings = text_resource.untranslated_strings(to_languages[0])
    assert_equal 2, untranslated_strings.length
    assert_equal 3, text_resource.count_words(untranslated_strings, text_resource.language, nil, false, 'test-all')

    # change again the original text and see that the status goes back

    # --- edit the original ---
    xml_http_request(:get, url_for(controller: :resource_strings, action: :edit, text_resource_id: text_resource.id, id: resource_string.id))
    assert_response :success

    assert assigns(:editing_original)

    updated_txt = 'modified original text - again'
    xml_http_request(:put, url_for(controller: :resource_strings, action: :update, text_resource_id: text_resource.id, id: resource_string.id),
                     resource_string: { txt: updated_txt }, req: 'save')
    assert_response :success

    resource_string.reload

    assert_equal updated_txt, resource_string.txt

    resource_string.string_translations.each { |string_translation| assert_equal STRING_TRANSLATION_NEEDS_UPDATE, string_translation.status }

    assert_equal 3, text_resource.untranslated_strings(to_languages[0]).length

    logout(session)

    # --- log in as translator and apply for the two jobs ---
    translator = users(:orit)
    session = login(translator)

    get(url_for(controller: :translator, action: :open_work))
    assert_response :success

    open_text_resource_projects = assigns(:open_text_resource_projects)
    assert open_text_resource_projects
    assert_equal to_languages.length, open_text_resource_projects.length

    # --- view the project ---
    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    open_text_resource_projects.each do |resource_language|
      get(url_for(controller: :resource_chats, action: :new, text_resource_id: text_resource.id, resource_lang_id: resource_language.id))
      assert_response :success

      resource_chats_count = text_resource.resource_chats.count

      # apply for this job
      post(url_for(controller: :resource_chats, action: :create, text_resource_id: text_resource.id),
           resource_chat: { resource_language_id: resource_language.id }, message: 'hello', apply: 0)
      assert_response :redirect

      text_resource.reload
      assert_equal resource_chats_count + 1, text_resource.resource_chats.count
      resource_chat = ResourceChat.last

      assert_equal translator, resource_chat.translator
      assert_equal RESOURCE_CHAT_NOT_APPLIED, resource_chat.status
      assert_equal 1, resource_chat.messages.length

      check_emails_delivered(1)

      get(url_for(controller: :resource_chats, action: :show, text_resource_id: text_resource.id, id: resource_chat.id))
      assert_response :success
      assert_equal assigns(:status_actions), [['Apply for this work', RESOURCE_CHAT_APPLIED]]

      post(url_for(controller: :resource_chats, action: :update_application_status, text_resource_id: text_resource.id, id: resource_chat.id),
           status: RESOURCE_CHAT_APPLIED)
      assert_response :redirect
      resource_chat.reload
      assert_equal RESOURCE_CHAT_APPLIED, resource_chat.status

      check_emails_delivered(1)

    end

    logout(session)

    # --- accept the applications ---
    session = login(client)

    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    assert_equal to_languages.length, text_resource.resource_chats.length

    text_resource.resource_chats.each do |resource_chat|
      get(url_for(controller: :resource_chats, action: :show, text_resource_id: text_resource.id, id: resource_chat.id))
      assert_response :success

      post(url_for(controller: :resource_chats, action: :update_application_status, text_resource_id: text_resource.id, id: resource_chat.id),
           status: RESOURCE_CHAT_ACCEPTED)
      assert_response :redirect

      check_emails_delivered(1)

      resource_chat.reload
      assert_equal RESOURCE_CHAT_ACCEPTED, resource_chat.status

      # also, send a message
      post(url_for(controller: :resource_chats, action: :create_message, text_resource_id: text_resource.id, id: resource_chat.id, format: :js),
           body: 'this is what I want to say', max_idx: 1, for_who1: translator.id)
      assert_response :success

      resource_chat.reload
      assert_equal 2, resource_chat.messages.length

      check_emails_delivered(1)

    end

    # send to translation
    client_account = client.find_or_create_account(DEFAULT_CURRENCY_ID)
    client_account.balance = 10000
    client_account.save

    assert_select 'div#missing_funds', false

    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    language_accounts = {}
    language_chats = {}
    text_resource.resource_chats.each do |resource_chat|

      client_account.reload
      before_balance = client_account.balance

      assert_equal 0, resource_chat.word_count

      post(url_for(controller: :resource_chats, action: :start_translations, text_resource_id: text_resource.id, selected_chats: [resource_chat.id]))
      assert_response :redirect

      check_emails_delivered(1)

      resource_chat.reload

      resource_language = resource_chat.resource_language
      assert_equal 1, resource_language.money_accounts.length
      resource_account = resource_language.money_accounts[0]

      language_accounts[resource_language.language] = resource_account

      client_account.reload
      paid = before_balance - client_account.balance
      assert paid > 0

      assert_same_amount(paid, resource_account.balance)

      assert_not_equal 0, resource_chat.word_count

      language_chats[resource_chat.resource_language.language] = resource_chat

    end

    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    text_resource.resource_languages.each do |resource_language|
      resource_language.resource_chats.each do |resource_chat|
        counted_words = resource_chat.real_word_count
        assert_equal resource_chat.word_count, counted_words
      end
    end

    logout(session)

    # --- now, do all the translation ---

    session = login(translator)

    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    get(url_for(controller: :resource_strings, action: :index, text_resource_id: text_resource.id))
    assert_response :success

    resource_string = assigns(:next_in_progress_str)
    assert resource_string

    translator_account = translator.find_or_create_account(DEFAULT_CURRENCY_ID)
    root_account = RootAccount.first
    unless root_account
      root_account = RootAccount.create!(balance: 0, currency_id: DEFAULT_CURRENCY_ID)
    end

    # no emails until here
    check_emails_delivered(0)

    max_translation_count = text_resource.resource_strings.count
    translated_count = 0
    while resource_string && (translated_count <= max_translation_count)
      get(url_for(controller: :resource_strings, action: :show, text_resource_id: text_resource.id, id: resource_string.id))
      assert_response :success

      is_last = assigns(:prev_in_progress_str).blank? && assigns(:next_in_progress_str).blank?
      assert_equal is_last, (translated_count == (max_translation_count - 1))

      next_str = assigns(:next_in_progress_str)
      assert_equal resource_string, assigns(:resource_string)

      to_languages.each do |tl|
        assert resource_string.user_can_edit_translation(translator, tl)

        language_account = language_accounts[tl]
        assert language_account

        # remember the balance before the translation
        language_account.reload
        before_language_balance = language_account.balance

        translator_account.reload
        before_translator_account = translator_account.balance

        root_account.reload
        before_root_balance = root_account.balance

        resource_chat = language_chats[tl]
        assert resource_chat
        before_word_count = resource_chat.word_count

        word_count = text_resource.count_words([resource_string], text_resource.language, nil)
        amount = word_count * resource_chat.resource_language.translation_amount

        # translate the string
        xml_http_request(:post, url_for(controller: :resource_strings, action: :edit_translation, text_resource_id: text_resource.id, id: resource_string.id, lang_id: tl.id))
        assert_response :success

        assert assigns(:editing)

        updated_translation = "updated translation to #{tl.name} - this can be pretty long"
        xml_http_request(:post, url_for(controller: :resource_strings, action: :update_translation, text_resource_id: text_resource.id, id: resource_string.id, lang_id: tl.id),
                         string_translation: { txt: updated_translation }, complete_translation: 1, req: 'save')
        assert_response :success

        # the last call should say that the translation is complete
        translation_complete = assigns(:translation_complete)
        if translated_count == (max_translation_count - 1)
          assert_equal true, translation_complete
        else
          assert_equal false, translation_complete
        end

        resource_string.reload

        string_translation = resource_string.string_translations.where('language_id=?', tl.id).first
        assert string_translation

        assert_equal updated_translation, string_translation.txt
        assert_equal STRING_TRANSLATION_COMPLETE, string_translation.status

        assert string_translation.tu
        assert_equal TU_COMPLETE, string_translation.tu.status

        # check that the payment is OK
        fee_amount = amount * FEE_RATE
        net_amount = amount - fee_amount

        root_account.reload
        assert_same_amount(before_root_balance + fee_amount, root_account.balance)

        language_account.reload
        assert_same_amount(before_language_balance - amount, language_account.balance)

        assert language_account.balance >= 0

        translator_account.reload
        assert_same_amount(before_translator_account + net_amount, translator_account.balance)

        resource_chat.reload
        assert_equal before_word_count - word_count, resource_chat.word_count

        # check what happens if we double submit
        updated_translation = "updated translation to #{tl.name} - this is a longer translation, make sure we count correctly"
        xml_http_request(:post, url_for(controller: :resource_strings, action: :update_translation, text_resource_id: text_resource.id, id: resource_string.id, lang_id: tl.id),
                         string_translation: { txt: updated_translation }, complete_translation: 1, req: 'save')
        assert_response :success

      end

      # keep count of how many we've translated
      translated_count += 1

      # move to the next one
      resource_string = next_str

      # after each translation, make sure that the word count is still OK
      text_resource.reload
      text_resource.resource_languages.each do |resource_language|
        resource_language.resource_chats.each do |resource_chat|
          resource_chat.reload
          counted_words = resource_chat.real_word_count
          assert_equal resource_chat.word_count, counted_words
        end
      end

    end

    assert_equal max_translation_count, translated_count

    text_resource.resource_chats.each do |resource_chat|
      resource_chat.reload
      assert_equal 0, resource_chat.word_count
    end

    to_languages.each do |tl|
      language_account = language_accounts[tl]
      assert language_account

      assert_equal 0, language_account.balance
    end

    # indicate to the client that translation is complete
    get(url_for(controller: :resource_strings, action: :index, text_resource_id: text_resource.id))
    assert_response :success

    completed_chats = assigns(:completed_chats)
    assert completed_chats
    assert_equal text_resource.resource_chats.length, completed_chats.length

    completed_chats.each do |chat|
      get(url_for(controller: :resource_chats, action: :show, text_resource_id: text_resource.id, id: chat.id))
      assert_response :success

      post(url_for(controller: :resource_chats, action: :translation_complete, text_resource_id: text_resource.id, id: chat.id))
      assert_response :redirect

      chat.reload
      assert_equal RESOURCE_CHAT_TRANSLATOR_NEEDS_TO_REVIEW, chat.translation_status

      # notify the client that the translation is complete
      check_emails_delivered(2)
    end

    # indicate that review is completed
    text_resource.resource_chats.each do |resource_chat|
      post(url_for(controller: :resource_chats, action: :review_complete, text_resource_id: text_resource.id, id: resource_chat.id))
      assert_response :redirect

      resource_chat.reload
      assert_equal RESOURCE_CHAT_TRANSLATION_REVIEWED, resource_chat.translation_status

      check_emails_delivered(1)
    end

    logout(session)

    # --- create the translated resource files ---
    session = login(client)

    text_resource.reload
    assert_equal 0, text_resource.resource_downloads.length

    post(url_for(controller: :text_resources, action: :create_translations, id: text_resource.id, resource_upload_id: resource_upload.id))
    assert_response :redirect

    text_resource.reload
    assert_equal to_languages.length, text_resource.resource_downloads.length

    to_languages.each do |tl|
      upload_translation = resource_upload.upload_translations.where('language_id=?', tl.id).first
      assert upload_translation

      resource_download = upload_translation.resource_download
      assert resource_download
      assert_equal text_resource, resource_download.text_resource

      assert resource_download.resource_download_stat
      assert_equal 3, resource_download.resource_download_stat.total
      assert_equal 3, resource_download.resource_download_stat.completed

      get(url_for(controller: :resource_downloads, action: :show, text_resource_id: text_resource.id, id: resource_download.id))
      assert_response :success
      assert_equal resource_download, assigns(:resource_download)

    end
  end

  # this test also assigns a reviewer
  def test_one_language_with_review
    init_email_deliveries

    delete_all

    checker = PeriodicChecker.new(Time.now)
    cnt = checker.per_profile_mailer
    assert_equal 0, cnt
    check_emails_delivered(0)

    client = users(:amir)

    # get ready with a reviewer
    reviewer = users(:guy)
    reviewer.update_attributes(level: EXPERT_TRANSLATOR)

    # before this project, there is no open work for review
    assert_equal 0, reviewer.open_managed_works.length

    # -- set up the project

    session = login(client)

    get(url_for(controller: :text_resources, action: :index))
    assert_response :success

    get(url_for(controller: :text_resources, action: :new))
    assert_response :success

    # --- create the project ---
    language = languages(:English)
    name = 'Test proj'
    description = 'this is what it is about'

    text_resource_count = TextResource.count

    post(url_for(controller: :text_resources, action: :create), text_resource: { name: name, description: description, language_id: language.id })
    assert_response :redirect

    assert_equal text_resource_count + 1, TextResource.count

    text_resource = TextResource.all.to_a[-1]
    assert_equal text_resource.name, name
    assert_equal text_resource.description, description
    assert_equal text_resource.language, language

    # --- view the project ---
    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    # --- choose translation languages ---
    xml_http_request(:post, url_for(controller: :text_resources, action: :edit_languages, id: text_resource.id, format: :js), req: 'show')
    assert_response :success

    assert assigns(:show_edit_languages)
    assert assigns(:languages)

    languages = assigns(:languages)
    assert languages.length >= 2, 'not enough translation languages'

    to_language_dic = {}
    to_languages = [languages(:Spanish)]
    to_languages.each do |tl|
      assert languages.key?(tl.name)
      to_language_dic[tl.id] = 1
    end

    post(url_for(controller: :text_resources, action: :edit_languages, id: text_resource.id, format: :js),
         req: 'save', language: to_language_dic)
    assert_response :redirect

    text_resource.reload
    assert_equal to_languages.length, text_resource.resource_languages.length

    to_languages.each do |tl|
      rl = text_resource.resource_languages.where('language_id=?', tl.id).first
      assert rl

      # check that review is enabled by default
      managed_work = rl.managed_work
      assert managed_work
      assert_equal MANAGED_WORK_ACTIVE, managed_work.active
      assert_equal MANAGED_WORK_CREATED, managed_work.translation_status
      assert_nil managed_work.translator
    end

    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    resource_format = ResourceFormat.where('name=?', 'Delphi').first
    assert resource_format

    # --- reviewers are notified about new work
    cnt = checker.per_profile_mailer
    assert cnt > 0
    check_emails_delivered(cnt)

    # --- upload the project ---

    resource_upload_count = ResourceUpload.count

    # upload
    fdata = fixture_file_upload('char_conversion/delphi_very_short.txt', 'application/octet-stream')
    multipart_post(url_for(controller: :resource_uploads, action: :create, text_resource_id: text_resource.id),
                   resource_upload: { uploaded_data: fdata }, resource_format_id: resource_format.id)
    assert_response :success

    resource_strings = assigns(:resource_strings)
    assert resource_strings
    assert_equal 3, resource_strings.length

    assert_equal resource_upload_count + 1, ResourceUpload.count

    resource_upload = ResourceUpload.all.to_a[-1]
    assert_nil resource_upload.normal_user

    post(url_for(controller: :resource_uploads, action: :scan_resource, text_resource_id: text_resource.id, id: resource_upload.id), string_idx_param(resource_strings))
    assert_response :redirect

    text_resource.reload

    assert_equal 3, text_resource.resource_strings.length

    # --- log in as translator and apply for the two jobs ---
    translator = users(:orit)
    session = login(translator)

    get(url_for(controller: :translator, action: :open_work))
    assert_response :success

    open_text_resource_projects = assigns(:open_text_resource_projects)
    assert open_text_resource_projects
    assert_equal to_languages.length, open_text_resource_projects.length

    # --- view the project ---
    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    open_text_resource_projects.each do |resource_language|
      get(url_for(controller: :resource_chats, action: :new, text_resource_id: text_resource.id, resource_lang_id: resource_language.id))
      assert_response :success

      resource_chats_count = text_resource.resource_chats.count

      # apply for this job
      post(url_for(controller: :resource_chats, action: :create, text_resource_id: text_resource.id),
           resource_chat: { resource_language_id: resource_language.id }, message: 'hello', apply: 1)
      assert_response :redirect

      text_resource.reload
      assert_equal resource_chats_count + 1, text_resource.resource_chats.count
      resource_chat = text_resource.resource_chats[-1]

      assert_equal translator, resource_chat.translator
      assert_equal RESOURCE_CHAT_APPLIED, resource_chat.status
      assert_equal 1, resource_chat.messages.length

      check_emails_delivered(1)
    end

    logout(session)

    # --- accept the applications ---
    session = login(client)

    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    assert_equal to_languages.length, text_resource.resource_chats.length

    text_resource.resource_chats.each do |resource_chat|
      get(url_for(controller: :resource_chats, action: :show, text_resource_id: text_resource.id, id: resource_chat.id))
      assert_response :success

      post(url_for(controller: :resource_chats, action: :update_application_status, text_resource_id: text_resource.id, id: resource_chat.id),
           status: RESOURCE_CHAT_ACCEPTED)
      assert_response :redirect

      check_emails_delivered(1)

      resource_chat.reload
      assert_equal RESOURCE_CHAT_ACCEPTED, resource_chat.status

      # also, send a message
      post(url_for(controller: :resource_chats, action: :create_message, text_resource_id: text_resource.id, id: resource_chat.id, format: :js),
           body: 'this is what I want to say', max_idx: 1, for_who1: translator.id)
      assert_response :success

      resource_chat.reload
      assert_equal 2, resource_chat.messages.length

      check_emails_delivered(1) # the reviewer is getting a copy too

    end

    # send to translation
    client_account = client.find_or_create_account(DEFAULT_CURRENCY_ID)
    client_account.balance = 10000
    client_account.save

    assert_select 'div#missing_funds', false

    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    language_accounts = {}
    language_chats = {}
    text_resource.resource_chats.each do |resource_chat|

      client_account.reload
      before_balance = client_account.balance

      assert_equal 0, resource_chat.word_count

      post(url_for(controller: :resource_chats, action: :start_translations, text_resource_id: text_resource.id, selected_chats: [resource_chat.id]))
      assert_response :redirect

      check_emails_delivered(1) # only the translator is notified

      resource_chat.reload

      resource_language = resource_chat.resource_language
      assert_equal 1, resource_language.money_accounts.length
      resource_account = resource_language.money_accounts[0]

      language_accounts[resource_language.language] = resource_account

      client_account.reload
      paid = before_balance - client_account.balance
      assert paid > 0

      assert_same_amount(paid, resource_account.balance)

      assert_not_equal 0, resource_chat.word_count

      language_chats[resource_chat.resource_language.language] = resource_chat

    end

    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    text_resource.resource_languages.each do |resource_language|
      resource_language.resource_chats.each do |resource_chat|
        counted_words = resource_chat.real_word_count
        assert_equal resource_chat.word_count, counted_words
      end
    end

    logout(session)

    # --- now, do all the translation ---

    session = login(translator)

    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    get(url_for(controller: :resource_strings, action: :index, text_resource_id: text_resource.id))
    assert_response :success

    resource_string = assigns(:next_in_progress_str)
    assert resource_string

    translator_account = translator.find_or_create_account(DEFAULT_CURRENCY_ID)
    root_account = RootAccount.first
    unless root_account
      root_account = RootAccount.create!(balance: 0, currency_id: DEFAULT_CURRENCY_ID)
    end

    # no emails until here
    check_emails_delivered(0)

    max_translation_count = text_resource.resource_strings.count
    translated_count = 0
    while resource_string && (translated_count <= max_translation_count)
      get(url_for(controller: :resource_strings, action: :show, text_resource_id: text_resource.id, id: resource_string.id))
      assert_response :success

      is_last = assigns(:prev_in_progress_str).blank? && assigns(:next_in_progress_str).blank?
      assert_equal is_last, (translated_count == (max_translation_count - 1))

      next_str = assigns(:next_in_progress_str)
      assert_equal resource_string, assigns(:resource_string)

      to_languages.each do |tl|
        assert resource_string.user_can_edit_translation(translator, tl)

        language_account = language_accounts[tl]
        assert language_account

        # remember the balance before the translation
        language_account.reload
        before_language_balance = language_account.balance

        translator_account.reload
        before_translator_account = translator_account.balance

        root_account.reload
        before_root_balance = root_account.balance

        resource_chat = language_chats[tl]
        assert resource_chat
        before_word_count = resource_chat.word_count

        word_count = text_resource.count_words([resource_string], text_resource.language, nil)
        amount = word_count * resource_chat.resource_language.translation_amount

        # translate the string
        xml_http_request(:post, url_for(controller: :resource_strings, action: :edit_translation, text_resource_id: text_resource.id, id: resource_string.id, lang_id: tl.id))
        assert_response :success

        assert assigns(:editing)

        updated_translation = "updated translation to #{tl.name} - this can be pretty long"
        xml_http_request(:post, url_for(controller: :resource_strings, action: :update_translation, text_resource_id: text_resource.id, id: resource_string.id, lang_id: tl.id),
                         string_translation: { txt: updated_translation }, complete_translation: 1, req: 'save')
        assert_response :success

        resource_string.reload

        string_translation = resource_string.string_translations.where('language_id=?', tl.id).first
        assert string_translation

        assert_equal updated_translation, string_translation.txt
        assert_equal STRING_TRANSLATION_COMPLETE, string_translation.status

        # check that the payment is OK
        fee_amount = amount * FEE_RATE
        net_amount = amount - fee_amount

        root_account.reload
        assert_same_amount(before_root_balance + fee_amount, root_account.balance)

        language_account.reload
        assert_same_amount(before_language_balance - amount, language_account.balance)

        assert language_account.balance >= 0

        translator_account.reload
        assert_same_amount(before_translator_account + net_amount, translator_account.balance)

        resource_chat.reload
        assert_equal before_word_count - word_count, resource_chat.word_count

        # check what happens if we double submit
        updated_translation = "updated translation to #{tl.name} - this is a longer translation, make sure we count correctly"
        xml_http_request(:post, url_for(controller: :resource_strings, action: :update_translation, text_resource_id: text_resource.id, id: resource_string.id, lang_id: tl.id),
                         string_translation: { txt: updated_translation }, complete_translation: 1, req: 'save')
        assert_response :success

      end

      # keep count of how many we've translated
      translated_count += 1

      # move to the next one
      resource_string = next_str

      # after each translation, make sure that the word count is still OK
      text_resource.reload
      text_resource.resource_languages.each do |resource_language|
        resource_language.resource_chats.each do |resource_chat|
          resource_chat.reload
          counted_words = resource_chat.real_word_count
          assert_equal resource_chat.word_count, counted_words
        end
      end

    end

    assert_equal max_translation_count, translated_count

    text_resource.resource_chats.each do |resource_chat|
      resource_chat.reload
      assert_equal 0, resource_chat.word_count
    end

    # there is still money for the reviewer
    to_languages.each do |tl|
      language_account = language_accounts[tl]
      assert language_account

      assert language_account.balance > 0
    end

    # indicate to the client that translation is complete
    get(url_for(controller: :resource_strings, action: :index, text_resource_id: text_resource.id))
    assert_response :success

    completed_chats = assigns(:completed_chats)
    assert completed_chats
    assert_equal text_resource.resource_chats.length, completed_chats.length

    completed_chats.each do |chat|
      get(url_for(controller: :resource_chats, action: :show, text_resource_id: text_resource.id, id: chat.id))
      assert_response :success

      post(url_for(controller: :resource_chats, action: :translation_complete, text_resource_id: text_resource.id, id: chat.id))
      assert_response :redirect

      chat.reload
      assert_equal RESOURCE_CHAT_TRANSLATION_COMPLETE, chat.translation_status

      # notify the client that the translation is complete
      check_emails_delivered(1) # since there is a reviewer, only the client is getting the email
    end

    # ------- log in as the reviewer and review all strings ---------

    logout(session)

    # check that the reviewer sees this open job
    assert_equal 1, reviewer.open_managed_works.length
    managed_work = ManagedWork.find(reviewer.open_managed_works[0].managed_work_id)
    assert_equal text_resource, managed_work.owner.text_resource

    assert_nil managed_work.translator

    session = login(reviewer)

    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    # make sure that the reviewer can actually be a reviewer in this project
    assert managed_work.translator_can_apply_to_review(reviewer)

    post(url_for(controller: :managed_works, action: :be_reviewer, id: managed_work.id))
    assert_response :redirect

    managed_work.reload
    assert_equal reviewer, managed_work.translator

    get(url_for(controller: :resource_strings, action: :index, text_resource_id: text_resource.id))
    assert_response :success

    # check that translators and reviewers get messages now
    text_resource.resource_chats.each do |resource_chat|
      chat_messages = resource_chat.messages.length

      # send a message. It goes to both the translator and reviewer
      post(url_for(controller: :resource_chats, action: :create_message, text_resource_id: text_resource.id, id: resource_chat.id, format: :js),
           body: 'Message in the review process. Both should get it', max_idx: 2, for_who1: translator.id, for_who2: reviewer.id)
      assert_response :success

      resource_chat.reload
      assert_equal chat_messages + 1, resource_chat.messages.length

      check_emails_delivered(2)
    end

    get(url_for(controller: :resource_strings, action: :index, text_resource_id: text_resource.id, set_args: 1))
    assert_response :success

    assert assigns(:is_reviewer)
    next_in_progress_str = assigns(:next_in_progress_str)
    assert next_in_progress_str
    assert_equal text_resource.resource_strings[0], next_in_progress_str

    review_idx = 0

    # record the client's balance
    client_account.reload
    balance_before_review = client_account.balance

    # adding some junk credit, so that we can see it refunded later
    text_resource.resource_chats[0].resource_language.money_accounts.each do |money_account|
      money_account.reload
      money_account.balance += 0.02
      money_account.save
    end

    # REVIEW: all the strings
    text_resource.resource_strings.each do |rs|
      get(url_for(controller: :resource_strings, action: :show, text_resource_id: text_resource.id, id: rs.id))
      assert_response :success

      next_in_progress_str = assigns(:next_in_progress_str)
      if review_idx != (text_resource.resource_strings.length - 1)
        assert next_in_progress_str
        assert_equal text_resource.resource_strings[review_idx + 1], next_in_progress_str
      else
        assert_nil next_in_progress_str
      end

      review_idx += 1

      rs.string_translations.each do |string_translation|
        assert_equal 1, string_translation.pay_reviewer
        assert_equal REVIEW_PENDING_ALREADY_FUNDED, string_translation.review_status

        post(url_for(controller: :resource_strings, action: :complete_review, text_resource_id: text_resource.id, id: rs.id, lang_id: string_translation.language_id, format: :js))
        assert_response :success

        string_translation.reload

        assert_equal 0, string_translation.pay_reviewer
        assert_equal REVIEW_COMPLETED, string_translation.review_status

      end

    end

    # --------------------------------------------------------------------------------------------

    # the client gets a confirmation email
    check_emails_delivered(1)

    to_languages.each do |tl|
      language_account = language_accounts[tl]
      assert language_account

      # language_account.reload
      # assert_same_amount(0,language_account.balance)
    end

    managed_work.reload
    assert_equal MANAGED_WORK_COMPLETE, managed_work.translation_status

    logout(session)

    # check that all the money is transfered back to the client
    text_resource.resource_chats.each do |resource_chat|
      resource_chat.resource_language.money_accounts.each do |money_account|
        money_account.reload
        assert_same_amount(0, money_account.balance)
      end
    end

    client_account.reload
    assert client_account.balance > balance_before_review

    # check that all resource chats show complete status
    text_resource.resource_chats.each do |resource_chat|
      resource_chat.reload
      assert_equal RESOURCE_CHAT_TRANSLATION_REVIEWED, resource_chat.translation_status
    end

  end

  # this test also assigns a reviewer
  def test_review_after_translation
    init_email_deliveries

    delete_all

    checker = PeriodicChecker.new(Time.now)
    cnt = checker.per_profile_mailer
    assert_equal 0, cnt
    check_emails_delivered(0)

    client = users(:amir)

    # get ready with a reviewer
    reviewer = users(:guy)
    reviewer.update_attributes(level: EXPERT_TRANSLATOR)

    # before this project, there is no open work for review
    assert_equal 0, reviewer.open_managed_works.length

    # -- set up the project

    session = login(client)

    get(url_for(controller: :text_resources, action: :index))
    assert_response :success

    get(url_for(controller: :text_resources, action: :new))
    assert_response :success

    # --- create the project ---
    language = languages(:English)
    name = 'Test proj'
    description = 'this is what it is about'

    text_resource_count = TextResource.count

    post(url_for(controller: :text_resources, action: :create), text_resource: { name: name, description: description, language_id: language.id })
    assert_response :redirect

    assert_equal text_resource_count + 1, TextResource.count

    text_resource = TextResource.all.to_a[-1]
    assert_equal text_resource.name, name
    assert_equal text_resource.description, description
    assert_equal text_resource.language, language

    # --- view the project ---
    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    # --- choose translation languages ---
    xml_http_request(:post, url_for(controller: :text_resources, action: :edit_languages, id: text_resource.id, format: :js), req: 'show')
    assert_response :success

    assert assigns(:show_edit_languages)
    assert assigns(:languages)

    languages = assigns(:languages)
    assert languages.length >= 2, 'not enough translation languages'

    to_language_dic = {}
    to_languages = [languages(:Spanish)]
    to_languages.each do |tl|
      assert languages.key?(tl.name)
      to_language_dic[tl.id] = 1
    end

    post(url_for(controller: :text_resources, action: :edit_languages, id: text_resource.id, format: :js),
         req: 'save', language: to_language_dic)
    assert_response :redirect

    text_resource.reload
    assert_equal to_languages.length, text_resource.resource_languages.length

    to_languages.each do |tl|
      rl = text_resource.resource_languages.where('language_id=?', tl.id).first
      assert rl

      # check that review is enabled by default
      managed_work = rl.managed_work
      assert managed_work
      assert_equal MANAGED_WORK_ACTIVE, managed_work.active
      assert_equal MANAGED_WORK_CREATED, managed_work.translation_status
      assert_nil managed_work.translator
    end

    # --- disable the review. we will enable it later ---
    text_resource.resource_languages.each do |rl|
      assert rl.managed_work
      managed_work = rl.managed_work
      assert_equal MANAGED_WORK_ACTIVE, managed_work.active

      post(url_for(controller: :managed_works, action: :update_status, id: managed_work.id, active: MANAGED_WORK_INACTIVE, format: :js))
      assert_response :success

      managed_work.reload
      assert_equal MANAGED_WORK_INACTIVE, managed_work.active
    end

    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    resource_format = ResourceFormat.where('name=?', 'Delphi').first
    assert resource_format

    # --- translators are still not notified (no strings uploaded) ---
    cnt = checker.per_profile_mailer
    assert_equal 0, cnt
    check_emails_delivered(cnt)

    # --- upload the project ---

    resource_upload_count = ResourceUpload.count

    # upload
    fdata = fixture_file_upload('char_conversion/delphi_very_short.txt', 'application/octet-stream')
    multipart_post(url_for(controller: :resource_uploads, action: :create, text_resource_id: text_resource.id),
                   resource_upload: { uploaded_data: fdata }, resource_format_id: resource_format.id)
    assert_response :success

    resource_strings = assigns(:resource_strings)
    assert resource_strings
    assert_equal 3, resource_strings.length

    assert_equal resource_upload_count + 1, ResourceUpload.count

    resource_upload = ResourceUpload.all.to_a[-1]
    assert_nil resource_upload.normal_user

    post(url_for(controller: :resource_uploads, action: :scan_resource, text_resource_id: text_resource.id, id: resource_upload.id), string_idx_param(resource_strings))
    assert_response :redirect

    text_resource.reload

    assert_equal 3, text_resource.resource_strings.length

    # --- log in as translator and apply for the two jobs ---
    translator = users(:orit)
    session = login(translator)

    get(url_for(controller: :translator, action: :open_work))
    assert_response :success

    open_text_resource_projects = assigns(:open_text_resource_projects)
    assert open_text_resource_projects
    assert_equal to_languages.length, open_text_resource_projects.length

    # --- view the project ---
    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    open_text_resource_projects.each do |resource_language|
      get(url_for(controller: :resource_chats, action: :new, text_resource_id: text_resource.id, resource_lang_id: resource_language.id))
      assert_response :success

      resource_chats_count = text_resource.resource_chats.count

      # apply for this job
      post(url_for(controller: :resource_chats, action: :create, text_resource_id: text_resource.id),
           resource_chat: { resource_language_id: resource_language.id }, message: 'hello', apply: 1)
      assert_response :redirect

      text_resource.reload
      assert_equal resource_chats_count + 1, text_resource.resource_chats.count
      resource_chat = text_resource.resource_chats[-1]

      assert_equal translator, resource_chat.translator
      assert_equal RESOURCE_CHAT_APPLIED, resource_chat.status
      assert_equal 1, resource_chat.messages.length

      check_emails_delivered(1)
    end

    logout(session)

    # --- accept the applications ---
    session = login(client)

    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    assert_equal to_languages.length, text_resource.resource_chats.length

    text_resource.resource_chats.each do |resource_chat|
      get(url_for(controller: :resource_chats, action: :show, text_resource_id: text_resource.id, id: resource_chat.id))
      assert_response :success

      post(url_for(controller: :resource_chats, action: :update_application_status, text_resource_id: text_resource.id, id: resource_chat.id),
           status: RESOURCE_CHAT_ACCEPTED)
      assert_response :redirect

      check_emails_delivered(1)

      resource_chat.reload
      assert_equal RESOURCE_CHAT_ACCEPTED, resource_chat.status

      # also, send a message
      post(url_for(controller: :resource_chats, action: :create_message, text_resource_id: text_resource.id, id: resource_chat.id, format: :js),
           body: 'this is what I want to say', max_idx: 1, for_who1: translator.id)
      assert_response :success

      resource_chat.reload
      assert_equal 2, resource_chat.messages.length

      check_emails_delivered(1) # the reviewer is getting a copy too

    end

    # send to translation
    client_account = client.find_or_create_account(DEFAULT_CURRENCY_ID)
    client_account.balance = 10000
    client_account.save

    assert_select 'div#missing_funds', false

    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    language_accounts = {}
    language_chats = {}
    text_resource.resource_chats.each do |resource_chat|

      client_account.reload
      before_balance = client_account.balance

      assert_equal 0, resource_chat.word_count

      post(url_for(controller: :resource_chats, action: :start_translations, text_resource_id: text_resource.id, selected_chats: [resource_chat.id]))
      assert_response :redirect

      check_emails_delivered(1) # only the translator is notified

      resource_chat.reload

      resource_language = resource_chat.resource_language
      assert_equal 1, resource_language.money_accounts.length
      resource_account = resource_language.money_accounts[0]

      language_accounts[resource_language.language] = resource_account

      client_account.reload
      paid = before_balance - client_account.balance
      assert paid > 0

      assert_same_amount(paid, resource_account.balance)

      assert_not_equal 0, resource_chat.word_count

      language_chats[resource_chat.resource_language.language] = resource_chat

    end

    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    text_resource.resource_languages.each do |resource_language|
      resource_language.resource_chats.each do |resource_chat|
        counted_words = resource_chat.real_word_count
        assert_equal resource_chat.word_count, counted_words
      end
    end

    logout(session)

    # --- now, do all the translation ---

    session = login(translator)

    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    get(url_for(controller: :resource_strings, action: :index, text_resource_id: text_resource.id))
    assert_response :success

    resource_string = assigns(:next_in_progress_str)
    assert resource_string

    translator_account = translator.find_or_create_account(DEFAULT_CURRENCY_ID)
    root_account = RootAccount.first
    unless root_account
      root_account = RootAccount.create!(balance: 0, currency_id: DEFAULT_CURRENCY_ID)
    end

    # no emails until here
    check_emails_delivered(0)

    max_translation_count = text_resource.resource_strings.count
    translated_count = 0
    while resource_string && (translated_count <= max_translation_count)
      get(url_for(controller: :resource_strings, action: :show, text_resource_id: text_resource.id, id: resource_string.id))
      assert_response :success

      is_last = assigns(:prev_in_progress_str).blank? && assigns(:next_in_progress_str).blank?
      assert_equal is_last, (translated_count == (max_translation_count - 1))

      next_str = assigns(:next_in_progress_str)
      assert_equal resource_string, assigns(:resource_string)

      to_languages.each do |tl|
        assert resource_string.user_can_edit_translation(translator, tl)

        language_account = language_accounts[tl]
        assert language_account

        # remember the balance before the translation
        language_account.reload
        before_language_balance = language_account.balance

        translator_account.reload
        before_translator_account = translator_account.balance

        root_account.reload
        before_root_balance = root_account.balance

        resource_chat = language_chats[tl]
        assert resource_chat
        before_word_count = resource_chat.word_count

        word_count = text_resource.count_words([resource_string], text_resource.language, nil)
        amount = word_count * resource_chat.resource_language.translation_amount

        # translate the string
        xml_http_request(:post, url_for(controller: :resource_strings, action: :edit_translation, text_resource_id: text_resource.id, id: resource_string.id, lang_id: tl.id))
        assert_response :success

        assert assigns(:editing)

        updated_translation = "updated translation to #{tl.name} - this can be pretty long"
        xml_http_request(:post, url_for(controller: :resource_strings, action: :update_translation, text_resource_id: text_resource.id, id: resource_string.id, lang_id: tl.id),
                         string_translation: { txt: updated_translation }, complete_translation: 1, req: 'save')
        assert_response :success

        resource_string.reload

        string_translation = resource_string.string_translations.where('language_id=?', tl.id).first
        assert string_translation

        assert_equal updated_translation, string_translation.txt
        assert_equal STRING_TRANSLATION_COMPLETE, string_translation.status

        # check that the payment is OK
        fee_amount = amount * FEE_RATE
        net_amount = amount - fee_amount

        root_account.reload
        assert_same_amount(before_root_balance + fee_amount, root_account.balance)

        language_account.reload
        assert_same_amount(before_language_balance - amount, language_account.balance)

        assert language_account.balance >= 0

        translator_account.reload
        assert_same_amount(before_translator_account + net_amount, translator_account.balance)

        resource_chat.reload
        assert_equal before_word_count - word_count, resource_chat.word_count

        # check what happens if we double submit
        updated_translation = "updated translation to #{tl.name} - this is a longer translation, make sure we count correctly"
        xml_http_request(:post, url_for(controller: :resource_strings, action: :update_translation, text_resource_id: text_resource.id, id: resource_string.id, lang_id: tl.id),
                         string_translation: { txt: updated_translation }, complete_translation: 1, req: 'save')
        assert_response :success

      end

      # keep count of how many we've translated
      translated_count += 1

      # move to the next one
      resource_string = next_str

      # after each translation, make sure that the word count is still OK
      text_resource.reload
      text_resource.resource_languages.each do |resource_language|
        resource_language.resource_chats.each do |resource_chat|
          resource_chat.reload
          counted_words = resource_chat.real_word_count
          assert_equal resource_chat.word_count, counted_words
        end
      end

    end

    assert_equal max_translation_count, translated_count

    text_resource.resource_chats.each do |resource_chat|
      resource_chat.reload
      assert_equal 0, resource_chat.word_count
    end

    # All the money is used on the translation
    to_languages.each do |tl|
      language_account = language_accounts[tl]
      assert language_account

      assert_same_amount(0, language_account.balance)
    end

    # indicate to the client that translation is complete
    get(url_for(controller: :resource_strings, action: :index, text_resource_id: text_resource.id))
    assert_response :success

    completed_chats = assigns(:completed_chats)
    assert completed_chats
    assert_equal text_resource.resource_chats.length, completed_chats.length

    completed_chats.each do |chat|
      get(url_for(controller: :resource_chats, action: :show, text_resource_id: text_resource.id, id: chat.id))
      assert_response :success

      post(url_for(controller: :resource_chats, action: :translation_complete, text_resource_id: text_resource.id, id: chat.id))
      assert_response :redirect

      chat.reload
      assert_equal RESOURCE_CHAT_TRANSLATOR_NEEDS_TO_REVIEW, chat.translation_status

      # notify the client that the translation is complete
      check_emails_delivered(2) # no reviewer, translator is notified too
    end

    # ---- client pays for the review ----

    logout(session)

    checker = PeriodicChecker.new(Time.now)

    # first time, flush all existing notifications
    cnt = checker.per_profile_mailer

    # next, nothing new to notify
    cnt = checker.per_profile_mailer
    assert_equal 0, cnt
    check_emails_delivered(0)

    session = login(client)

    # --- enable the review ---
    text_resource.resource_languages.each do |rl|
      assert rl.managed_work
      managed_work = rl.managed_work
      assert_equal MANAGED_WORK_INACTIVE, managed_work.active

      post(url_for(controller: :managed_works, action: :update_status, id: managed_work.id, active: MANAGED_WORK_ACTIVE, format: :js))
      assert_response :success

      managed_work.reload
      assert_equal MANAGED_WORK_ACTIVE, managed_work.active

      chat = rl.selected_chat
      chat.reload
      assert_equal RESOURCE_CHAT_TRANSLATION_COMPLETE, chat.translation_status
    end

    text_resource.resource_chats.each do |resource_chat|

      client_account.reload
      before_balance = client_account.balance

      assert_equal 0, resource_chat.word_count

      post(url_for(controller: :resource_chats, action: :start_review, text_resource_id: text_resource.id, id: resource_chat.id))
      assert_response :redirect

      check_emails_delivered(0) # only the translator is notified

      resource_chat.reload
      resource_language = resource_chat.resource_language

      resource_account = language_accounts[resource_language.language]
      resource_account.reload

      client_account.reload
      paid = before_balance - client_account.balance
      assert paid > 0

      assert_same_amount(paid, resource_account.balance)

      assert_equal 0, resource_chat.word_count

    end

    # ------- log in as the reviewer and review all strings ---------

    # now, translators should be notified about the review jobs
    cnt = checker.per_profile_mailer
    assert cnt > 0
    check_emails_delivered(cnt)

    logout(session)

    # check that the reviewer sees this open job
    assert_equal 1, reviewer.open_managed_works.length
    managed_work = ManagedWork.find(reviewer.open_managed_works[0].managed_work_id)
    assert_equal text_resource, managed_work.owner.text_resource

    assert_nil managed_work.translator

    session = login(reviewer)

    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    post(url_for(controller: :managed_works, action: :be_reviewer, id: managed_work.id))
    assert_response :redirect

    managed_work.reload
    assert_equal reviewer, managed_work.translator

    get(url_for(controller: :resource_strings, action: :index, text_resource_id: text_resource.id))
    assert_response :success

    text_resource.resource_strings.each do |rs|
      get(url_for(controller: :resource_strings, action: :show, text_resource_id: text_resource.id, id: rs.id))
      assert_response :success

      rs.string_translations.each do |string_translation|
        assert_equal 1, string_translation.pay_reviewer
        assert_equal REVIEW_PENDING_ALREADY_FUNDED, string_translation.review_status

        post(url_for(controller: :resource_strings, action: :complete_review, text_resource_id: text_resource.id, id: rs.id, lang_id: string_translation.language_id, format: :js))
        assert_response :success

        string_translation.reload

        assert_equal 0, string_translation.pay_reviewer
        assert_equal REVIEW_COMPLETED, string_translation.review_status

      end

    end

    # the client gets a confirmation email
    check_emails_delivered(1)

    to_languages.each do |tl|
      language_account = language_accounts[tl]
      assert language_account

      language_account.reload

      assert_same_amount(0, language_account.balance)
    end

    managed_work.reload
    assert_equal MANAGED_WORK_COMPLETE, managed_work.translation_status

    # check that all resource chats show complete status
    text_resource.resource_chats.each do |resource_chat|
      resource_chat.reload
      assert_equal RESOURCE_CHAT_TRANSLATION_REVIEWED, resource_chat.translation_status
    end

    logout(session)

  end

  def test_add_texts
    init_email_deliveries

    client = users(:amir)

    session = login(client)

    get(url_for(controller: :text_resources, action: :index))
    assert_response :success

    get(url_for(controller: :text_resources, action: :new))
    assert_response :success

    # --- create the project ---
    language = languages(:English)
    name = 'Incremental add strings project'
    description = 'this is what it is about'

    text_resource_count = TextResource.count

    post(url_for(controller: :text_resources, action: :create),
         params: { text_resource: { name: name, description: description, language_id: language.id } })
    assert_response :redirect

    assert_equal text_resource_count + 1, TextResource.count

    text_resource = TextResource.all.to_a[-1]
    assert_equal text_resource.name, name
    assert_equal text_resource.description, description
    assert_equal text_resource.language, language

    # --- view the project ---
    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    resource_format = ResourceFormat.where('name=?', 'Delphi').first
    assert resource_format

    resource_upload_count = ResourceUpload.count

    # first upload
    fdata = fixture_file_upload('char_conversion/v1/delph_resource.txt', 'application/octet-stream')
    multipart_post(url_for(controller: :resource_uploads, action: :create, text_resource_id: text_resource.id),
                   resource_upload: { uploaded_data: fdata }, resource_format_id: resource_format.id)
    assert_response :success

    assert_equal resource_upload_count + 1, ResourceUpload.count

    resource_upload = ResourceUpload.all.to_a[-1]
    assert_nil resource_upload.normal_user

    resource_strings = assigns(:resource_strings)
    post(url_for(controller: :resource_uploads, action: :scan_resource, text_resource_id: text_resource.id, id: resource_upload.id), string_idx_param(resource_strings))
    assert_response :redirect

    text_resource.reload

    assert_equal 3, text_resource.resource_strings.length

    # 2nd upload, add strings
    # first upload
    fdata = fixture_file_upload('char_conversion/v2/delph_resource.txt', 'application/octet-stream')
    multipart_post(url_for(controller: :resource_uploads, action: :create, text_resource_id: text_resource.id),
                   resource_upload: { uploaded_data: fdata }, resource_format_id: resource_format.id)
    assert_response :success

    assert_equal resource_upload_count + 2, ResourceUpload.count

    resource_upload = ResourceUpload.all.to_a[-1]
    assert_nil resource_upload.normal_user

    resource_strings = assigns(:resource_strings)
    post(url_for(controller: :resource_uploads, action: :scan_resource, text_resource_id: text_resource.id, id: resource_upload.id), string_idx_param(resource_strings))
    assert_response :redirect

    assert_equal 3, assigns(:existing_strings_count)
    assert_equal 468, assigns(:added_strings_count)

    # 3nd upload, nothing changes
    fdata = fixture_file_upload('char_conversion/v2/delph_resource.txt', 'application/octet-stream')
    multipart_post(url_for(controller: :resource_uploads, action: :create, text_resource_id: text_resource.id),
                   resource_upload: { uploaded_data: fdata }, resource_format_id: resource_format.id)
    assert_response :success

    assert_equal resource_upload_count + 3, ResourceUpload.count

    resource_upload = ResourceUpload.all.to_a[-1]
    assert_nil resource_upload.normal_user

    post(url_for(controller: :resource_uploads, action: :scan_resource, text_resource_id: text_resource.id, id: resource_upload.id), string_idx_param(resource_strings))
    assert_response :redirect

    assert_equal 471, assigns(:existing_strings_count)
    assert_equal 0, assigns(:added_strings_count)

    # 4nd upload, new context created
    fdata = fixture_file_upload('char_conversion/delphi_med.txt', 'application/octet-stream')
    multipart_post(url_for(controller: :resource_uploads, action: :create, text_resource_id: text_resource.id),
                   resource_upload: { uploaded_data: fdata }, resource_format_id: resource_format.id)
    assert_response :success

    assert_equal resource_upload_count + 4, ResourceUpload.count

    resource_upload = ResourceUpload.all.to_a[-1]
    assert_nil resource_upload.normal_user

    post(url_for(controller: :resource_uploads, action: :scan_resource, text_resource_id: text_resource.id, id: resource_upload.id), string_idx_param(resource_strings))
    assert_response :redirect

    assert_equal 471, assigns(:added_strings_count)

    logout(session)

  end

  def pay_for_untranslated_string(client, _client_account, text_resource, language)
    client.reload

    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    assert_select 'div#missing_funds'

    invoices_count = client.invoices.count

    # construct the post
    word_count = {}
    untranslated_strings = {}
    total = 0
    args = {}
    text_resource.resource_languages.each do |resource_language|
      args["resource_language#{resource_language.id}"] = 1
      args["transaction_code#{resource_language.id}"] = TRANSFER_DEPOSIT_TO_RESOURCE_TRANSLATION

      untranslated_strings[resource_language] = text_resource.untranslated_strings(resource_language.language)
      language_word_count = text_resource.count_words(untranslated_strings[resource_language], language, nil)
      word_count[resource_language] = language_word_count

      total += resource_language.cost
    end

    total = total.ceil_money

    post(url_for(controller: :text_resources, action: :deposit_payment, id: text_resource.id), args)
    assert_response :redirect

    assert_equal invoices_count + 1, client.invoices.count
    invoice = client.invoices[-1]

    # check the total
    assert_same_amount(total, invoice.gross_amount)

    # check that we have the right number of money trasactions
    # we create a deposit transaction and a tax transaction ( +2 ).
    assert_equal text_resource.resource_languages.count + 2, invoice.money_transactions.count

    rl_transfers = 0
    invoice.money_transactions.each do |money_transaction|
      if money_transaction.target_account.class == UserAccount
        assert_same_amount(money_transaction.amount, total)
      elsif money_transaction.target_account.class == ResourceLanguageAccount
        assert_same_amount(money_transaction.amount, word_count[money_transaction.target_account.resource_language] * money_transaction.target_account.resource_language.translation_amount)
        rl_transfers += 1
      elsif money_transaction.target_account.class == TaxAccount
        # we are not setting taxes
        assert_same_amount(money_transaction.amount, 0)
      else
        assert false
      end
    end

    assert_equal text_resource.resource_languages.count, rl_transfers

    # before payment, all the translation should be missing
    text_resource.resource_languages.each do |resource_language|
      untranslated_strings[resource_language].each do |resource_string|
        resource_string.string_translations.where('language_id=?', resource_language.language_id).each do |string_translation|
          assert_equal STRING_TRANSLATION_MISSING, string_translation.status
        end
      end
    end

    # check the difference in the balance and word count
    resource_language_account_balance = {}
    resource_language_word_count = {}
    text_resource.resource_languages.each do |resource_language|
      resource_language_account = resource_language.money_accounts[0]
      resource_language_account_balance[resource_language] = resource_language_account.balance
      resource_language_word_count[resource_language] = resource_language.selected_chat.word_count
    end

    # --- pay for the invoice ---

    txn = 'txstr%d' % (PaypalMockReply.count + 1)
    fee = total * 0.03

    # now, do the PayPal IPN for this payment
    tx = PaypalMockReply.new(payer_email: client.email,
                             first_name: client.fname,
                             last_name: client.lname)

    tx.save
    tx.update_attributes(txn_id: txn,
                         business: Figaro.env.PAYPAL_BUSINESS_EMAIL,
                         mc_gross: total,
                         mc_currency: 'USD',
                         mc_fee: fee,
                         payment_status: 'Completed',
                         payer_status: 'verified',
                         invoice: invoice.id,
                         txn_type: 'web_accept')

    post(url_for(controller: :finance, action: :paypal_ipn), tx.attributes)
    assert_response :success
    assert_nil assigns['retry']
    assert_nil assigns['errors']

    invoice.reload

    assert_equal invoice.status, TXN_COMPLETED
    assert_equal invoice.txn, txn

    # the translators should have received start-work emails
    check_emails_delivered(text_resource.resource_languages.count + 1)

    # check that all the strings went to translation
    text_resource.resource_strings.each do |resource_string|
      resource_string.string_translations.each do |string_translation|
        string_translation.reload
        assert_equal STRING_TRANSLATION_BEING_TRANSLATED, string_translation.status
      end
    end

    # check that the resource language balances include the payment
    text_resource.resource_languages.each do |resource_language|
      resource_language_account = resource_language.money_accounts[0]
      resource_language_account.reload
      resource_language.selected_chat.reload

      assert_same_amount(resource_language_account_balance[resource_language] + word_count[resource_language] * resource_language.translation_amount, resource_language_account.balance)
      assert_equal (resource_language_word_count[resource_language] + word_count[resource_language]), resource_language.selected_chat.word_count
      resource_language.resource_chats.each do |resource_chat|
        counted_words = resource_chat.real_word_count
        assert_equal resource_chat.word_count, counted_words
      end
    end
    # Todo Investigate this failing paypal test - jon 02162017
    # test that the user sees a good 'thank you' page after payment
    # post(url_for(controller: :finance, action: :paypal_complete), tx: tx.txn_id)
    # assert_response :success

    # visit the invoice page
    get(url_for(controller: :finance, action: :invoice, id: invoice.id))
    assert_response :success

    # visit the project page
    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    # make sure that there's nothing more for translation
    text_resource.resource_languages.each do |resource_language|
      untranslated_strings = text_resource.untranslated_strings(resource_language.language)
      assert_equal 0, untranslated_strings.length
    end
  end

  def test_iphone_project_with_comments
    init_email_deliveries

    client = users(:amir)

    session = login(client)

    get(url_for(controller: :text_resources, action: :index))
    assert_response :success

    get(url_for(controller: :text_resources, action: :new))
    assert_response :success

    # --- create the project ---
    language = languages(:English)
    name = 'iPhone project'
    description = 'this is what it is about'

    text_resource_count = TextResource.count

    post(url_for(controller: :text_resources, action: :create), text_resource: { name: name, description: description, language_id: language.id })
    assert_response :redirect

    assert_equal text_resource_count + 1, TextResource.count

    text_resource = TextResource.all.to_a[-1]
    assert_equal text_resource.name, name
    assert_equal text_resource.description, description
    assert_equal text_resource.language, language

    # --- view the project ---
    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    resource_format = ResourceFormat.where('name=?', 'iPhone').first
    assert resource_format

    resource_upload_count = ResourceUpload.count

    # first upload
    fdata = fixture_file_upload('char_conversion/iphone.txt', 'application/octet-stream')
    multipart_post(url_for(controller: :resource_uploads, action: :create, text_resource_id: text_resource.id),
                   resource_upload: { uploaded_data: fdata }, resource_format_id: resource_format.id)
    assert_response :success

    assert_equal resource_upload_count + 1, ResourceUpload.count

    resource_upload = ResourceUpload.all.to_a[-1]
    assert_nil resource_upload.normal_user
    resource_strings = assigns(:resource_strings)
    assert_equal 30, resource_strings.length

    post(url_for(controller: :resource_uploads, action: :scan_resource, text_resource_id: text_resource.id, id: resource_upload.id), string_idx_param(resource_strings))
    assert_response :redirect

    text_resource.reload

    assert_equal resource_strings.length, text_resource.resource_strings.length

    assert_equal 'No comment provided by engineer.', text_resource.resource_strings[0].comment
    assert_nil text_resource.resource_strings[1].comment
    assert_nil text_resource.resource_strings[2].comment
    assert_equal 'Category string', text_resource.resource_strings[3].comment
    assert_equal 'Outside app folder moving application faild dialog', text_resource.resource_strings[4].comment
    assert_nil text_resource.resource_strings[5].comment

    assert_equal MAX_STR_LENGTH, text_resource.resource_strings[-1].token.length
    assert MAX_STR_LENGTH < text_resource.resource_strings[-1].txt.length

  end

  def test_string_updates
    init_email_deliveries

    client = users(:amir)

    session = login(client)

    get(url_for(controller: :text_resources, action: :index))
    assert_response :success

    get(url_for(controller: :text_resources, action: :new))
    assert_response :success

    # --- create the project ---
    language = languages(:English)
    name = 'iPhone project 2'
    description = 'this is what it is about'

    text_resource_count = TextResource.count

    post(url_for(controller: :text_resources, action: :create), text_resource: { name: name, description: description, language_id: language.id })
    assert_response :redirect

    assert_equal text_resource_count + 1, TextResource.count

    text_resource = TextResource.all.to_a[-1]
    assert_equal text_resource.name, name
    assert_equal text_resource.description, description
    assert_equal text_resource.language, language

    # create a language
    to_language_dic = {}
    to_languages = [languages(:Spanish), languages(:German)]
    to_languages.each do |tl|
      to_language_dic[tl.id] = 1
    end

    post(url_for(controller: :text_resources, action: :edit_languages, id: text_resource.id, format: :js),
         req: 'save', language: to_language_dic)
    assert_response :redirect

    text_resource.reload
    assert_equal to_languages.length, text_resource.resource_languages.length

    to_languages.each do |tl|
      assert text_resource.resource_languages.where('language_id=?', tl.id).first
    end

    # --- view the project ---
    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    resource_format = ResourceFormat.where('name=?', 'iPhone').first
    assert resource_format

    resource_upload_count = ResourceUpload.count

    # --- first upload ---
    fdata = fixture_file_upload('char_conversion/iphone.txt', 'application/octet-stream')
    multipart_post(url_for(controller: :resource_uploads, action: :create, text_resource_id: text_resource.id),
                   resource_upload: { uploaded_data: fdata }, resource_format_id: resource_format.id)
    assert_response :success

    assert_equal resource_upload_count + 1, ResourceUpload.count

    resource_upload = ResourceUpload.all.to_a[-1]
    assert_nil resource_upload.normal_user

    resource_strings = assigns(:resource_strings)

    post(url_for(controller: :resource_uploads, action: :scan_resource, text_resource_id: text_resource.id, id: resource_upload.id), string_idx_param(resource_strings))
    assert_response :redirect

    text_resource.reload

    assert_equal resource_strings.length, text_resource.resource_strings.length

    assert_equal 'No comment provided by engineer.', text_resource.resource_strings[0].comment
    assert_nil text_resource.resource_strings[1].comment
    assert_nil text_resource.resource_strings[2].comment
    assert_equal 'Category string', text_resource.resource_strings[3].comment
    assert_equal 'Outside app folder moving application faild dialog', text_resource.resource_strings[4].comment
    assert_nil text_resource.resource_strings[5].comment

    # --- mark one of the strings as being translated
    # we need to see this string blocked from updates
    text_resource.resource_strings[0].string_translations[0].update_attributes(status: STRING_TRANSLATION_BEING_TRANSLATED)

    # --- update ---
    fdata = fixture_file_upload('char_conversion/v2/iphone.txt', 'application/octet-stream')
    multipart_post(url_for(controller: :resource_uploads, action: :create, text_resource_id: text_resource.id),
                   resource_upload: { uploaded_data: fdata }, resource_format_id: resource_format.id)
    assert_response :success

    assert_equal resource_upload_count + 2, ResourceUpload.count

    resource_upload = ResourceUpload.all.to_a[-1]
    assert_nil resource_upload.normal_user

    post(url_for(controller: :resource_uploads, action: :scan_resource, text_resource_id: text_resource.id, id: resource_upload.id), string_idx_param(resource_strings))
    assert_response :redirect

    text_resource.reload

    assert_equal resource_strings.length, text_resource.resource_strings.length

    s1 = text_resource.resource_strings[0]
    s2 = text_resource.resource_strings[1]

    assert_equal 'All', s1.txt
    assert_equal 'drinks', s2.txt

  end

  def test_po_project
    init_email_deliveries

    client = users(:amir)

    session = login(client)

    get(url_for(controller: :text_resources, action: :index))
    assert_response :success

    get(url_for(controller: :text_resources, action: :new))
    assert_response :success

    # --- create the project ---
    language = languages(:English)
    name = 'PO project'
    description = 'this is what it is about'

    text_resource_count = TextResource.count

    post(url_for(controller: :text_resources, action: :create), text_resource: { name: name, description: description, language_id: language.id })
    assert_response :redirect

    assert_equal text_resource_count + 1, TextResource.count

    text_resource = TextResource.all.to_a[-1]
    assert_equal text_resource.name, name
    assert_equal text_resource.description, description
    assert_equal text_resource.language, language

    # --- view the project ---
    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    resource_format = ResourceFormat.where('name=?', 'PO').first
    assert resource_format

    resource_upload_count = ResourceUpload.count

    # first upload
    assert_difference 'ResourceUpload.count', 1 do
      fdata = fixture_file_upload('char_conversion/i18n_orig_thai4.po', 'application/octet-stream')
      multipart_post(url_for(controller: :resource_uploads, action: :create, text_resource_id: text_resource.id),
                     resource_upload: { uploaded_data: fdata }, resource_format_id: resource_format.id)
      assert_response :success
    end

    resource_upload = ResourceUpload.all.to_a[-1]
    assert_nil resource_upload.normal_user

    resource_strings = assigns(:resource_strings)
    post(url_for(controller: :resource_uploads, action: :scan_resource, text_resource_id: text_resource.id, id: resource_upload.id), string_idx_param(resource_strings))
    assert_response :redirect

    text_resource.reload

    assert_equal 254, text_resource.resource_strings.length

  end

  def test_payment_separate
    init_email_deliveries

    delete_all

    checker = PeriodicChecker.new(Time.now)
    cnt = checker.per_profile_mailer
    assert_equal 0, cnt
    check_emails_delivered(0)

    client = users(:amir)

    session = login(client)

    get(url_for(controller: :text_resources, action: :index))
    assert_response :success

    get(url_for(controller: :text_resources, action: :new))
    assert_response :success

    # --- create the project ---
    language = languages(:English)
    name = 'Test proj'
    description = 'this is what it is about'

    text_resource_count = TextResource.count

    post(url_for(controller: :text_resources, action: :create), text_resource: { name: name, description: description, language_id: language.id })
    assert_response :redirect

    assert_equal text_resource_count + 1, TextResource.count

    text_resource = TextResource.all.to_a[-1]
    assert_equal text_resource.name, name
    assert_equal text_resource.description, description
    assert_equal text_resource.language, language

    # **** in this test, we first upload the strings and then select the translation languages ****

    # --- upload the project ---

    resource_format = ResourceFormat.where('name=?', 'Delphi').first
    assert resource_format

    resource_upload_count = ResourceUpload.count

    # upload again, now accept
    fdata = fixture_file_upload('char_conversion/delphi_very_short.txt', 'application/octet-stream')
    multipart_post(url_for(controller: :resource_uploads, action: :create, text_resource_id: text_resource.id),
                   resource_upload: { uploaded_data: fdata }, resource_format_id: resource_format.id)
    assert_response :success

    assert_equal resource_upload_count + 1, ResourceUpload.count

    resource_upload = ResourceUpload.all.to_a[-1]
    assert_nil resource_upload.normal_user

    resource_strings = assigns(:resource_strings)
    post(url_for(controller: :resource_uploads, action: :scan_resource, text_resource_id: text_resource.id, id: resource_upload.id), string_idx_param(resource_strings))
    assert_response :redirect

    text_resource.reload

    assert_equal 3, text_resource.resource_strings.length

    # --- choose translation languages ---
    xml_http_request(:post, url_for(controller: :text_resources, action: :edit_languages, id: text_resource.id, format: :js), req: 'show')
    assert_response :success

    assert assigns(:show_edit_languages)
    assert assigns(:languages)

    languages = assigns(:languages)
    assert languages.length >= 2, 'not enough translation languages'

    to_language_dic = {}
    to_languages = [languages(:Spanish), languages(:German)]
    to_languages.each do |tl|
      assert languages.key?(tl.name)
      to_language_dic[tl.id] = 1
    end

    post(url_for(controller: :text_resources, action: :edit_languages, id: text_resource.id, format: :js),
         req: 'save', language: to_language_dic)
    assert_response :redirect

    text_resource.reload
    assert_equal to_languages.length, text_resource.resource_languages.length

    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    # --- disable the review ---
    text_resource.resource_languages.each do |rl|
      assert rl.managed_work
      managed_work = rl.managed_work
      assert_equal MANAGED_WORK_ACTIVE, managed_work.active

      post(url_for(controller: :managed_works, action: :update_status, id: managed_work.id, active: MANAGED_WORK_INACTIVE, format: :js))
      assert_response :success

      managed_work.reload
      assert_equal MANAGED_WORK_INACTIVE, managed_work.active
    end

    # --- see that translators are notified now ---
    cnt = checker.per_profile_mailer
    assert_not_equal 0, cnt
    check_emails_delivered(cnt)

    logout(session)

    # --- log in as translator and apply for the two jobs ---
    translator = users(:orit)
    session = login(translator)

    get(url_for(controller: :translator, action: :open_work))
    assert_response :success

    open_text_resource_projects = assigns(:open_text_resource_projects)
    assert open_text_resource_projects
    assert_equal to_languages.length, open_text_resource_projects.length

    # --- view the project ---
    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    open_text_resource_projects.each do |resource_language|
      get(url_for(controller: :resource_chats, action: :new, text_resource_id: text_resource.id, resource_lang_id: resource_language.id))
      assert_response :success

      resource_chats_count = text_resource.resource_chats.count

      # apply for this job
      post(url_for(controller: :resource_chats, action: :create, text_resource_id: text_resource.id),
           resource_chat: { resource_language_id: resource_language.id }, message: 'hello', apply: 1)
      assert_response :redirect

      text_resource.reload
      assert_equal resource_chats_count + 1, text_resource.resource_chats.count
      resource_chat = text_resource.resource_chats[-1]

      assert_equal translator, resource_chat.translator
      assert_equal RESOURCE_CHAT_APPLIED, resource_chat.status
      assert_equal 1, resource_chat.messages.length

      check_emails_delivered(1)
    end

    logout(session)

    # --- accept the applications ---
    session = login(client)

    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    assert_equal to_languages.length, text_resource.resource_chats.length

    text_resource.resource_chats.each do |resource_chat|
      get(url_for(controller: :resource_chats, action: :show, text_resource_id: text_resource.id, id: resource_chat.id))
      assert_response :success

      post(url_for(controller: :resource_chats, action: :update_application_status, text_resource_id: text_resource.id, id: resource_chat.id),
           status: RESOURCE_CHAT_ACCEPTED)
      assert_response :redirect

      check_emails_delivered(1)

      resource_chat.reload
      assert_equal RESOURCE_CHAT_ACCEPTED, resource_chat.status

      # also, send a message
      post(url_for(controller: :resource_chats, action: :create_message, text_resource_id: text_resource.id, id: resource_chat.id, format: :js),
           body: 'this is what I want to say', max_idx: 1, for_who1: translator.id)
      assert_response :success

      resource_chat.reload
      assert_equal 2, resource_chat.messages.length

      check_emails_delivered(1)
    end

    # --- create an invoice for this job ---

    # ZERO the clients account so that payment is required
    client_account = client.find_or_create_account(DEFAULT_CURRENCY_ID)
    client_account.balance = 0
    client_account.save

    pay_for_untranslated_string(client, client_account, text_resource, language)

    # --- now a string and pay for it
    get(url_for(controller: :resource_strings, action: :new, text_resource_id: text_resource.id))
    assert_response :success

    resource_strings_count = text_resource.resource_strings.count
    post(url_for(controller: :resource_strings, action: :create, text_resource_id: text_resource.id),
         resource_string: { token: 'newstr', txt: 'this is it' })
    assert_response :redirect

    text_resource.reload
    assert_equal resource_strings_count + 1, text_resource.resource_strings.count

    new_str = text_resource.resource_strings[-1]
    new_str.string_translations.each do |st|
      assert_nil st.txt
      assert_equal STRING_TRANSLATION_MISSING, st.status
    end

    client_account.reload
    client_account.balance = 0
    client_account.save

    pay_for_untranslated_string(client, client_account, text_resource, language)

    new_str.reload
    new_str.string_translations.each do |st|
      assert_nil st.txt
      assert_equal STRING_TRANSLATION_BEING_TRANSLATED, st.status
    end

    # --- send the strings to review too ---

    invoices_count = client.invoices.count

    # before payment, all the translation should be missing not for review
    text_resource.resource_strings.each do |resource_string|
      resource_string.string_translations.each do |string_translation|
        assert_equal REVIEW_NOT_NEEDED, string_translation.review_status
      end
    end

    # --- enable the review ---
    text_resource.resource_languages.each do |rl|
      managed_work = rl.managed_work

      post(url_for(controller: :managed_works, action: :update_status, id: managed_work.id, active: MANAGED_WORK_ACTIVE, format: :js))
      assert_response :success

      managed_work.reload
      assert_equal MANAGED_WORK_ACTIVE, managed_work.active
    end

    # zero the client's account, so that he needs to pay again
    client_account.reload
    client_account.update_attributes(balance: 0)

    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    assert_select 'div#missing_funds'

    # construct the post
    args = {}
    text_resource.resource_languages.each do |resource_language|
      args["resource_language#{resource_language.id}"] = 1
      args["transaction_code#{resource_language.id}"] = TRANSFER_DEPOSIT_TO_RESOURCE_REVIEW
    end

    post(url_for(controller: :text_resources, action: :deposit_payment, id: text_resource.id), args)
    assert_response :redirect

    client.reload
    assert_equal invoices_count + 1, client.invoices.count
    invoice = client.invoices[-1]

    # check the total
    word_count = text_resource.count_words(text_resource.resource_strings, language, nil)
    total = text_resource.resource_languages.inject(0) { |a, b| a + b.cost }
    total = total.ceil_money
    assert_same_amount(total, invoice.gross_amount)

    # check that we have the right number of money trasactions
    # one for deposit and other for tax ( +2 )
    assert_equal text_resource.resource_languages.count + 2, invoice.money_transactions.count

    rl_transfers = 0
    invoice.money_transactions.each do |money_transaction|
      if money_transaction.target_account.class == UserAccount
        assert_same_amount(money_transaction.amount, total)
      elsif money_transaction.target_account.class == ResourceLanguageAccount
        resource_language = money_transaction.target_account.resource_language
        assert_same_amount(money_transaction.amount, resource_language.translation_amount * word_count * 0.5)
        rl_transfers += 1
      elsif money_transaction.target_account.class == TaxAccount
        # we are not setting taxes
        assert_same_amount(money_transaction.amount, 0)
      else
        assert false
      end
    end

    assert_equal text_resource.resource_languages.count, rl_transfers

    # before payment, all the translation should be missing not for review
    text_resource.resource_strings.each do |resource_string|
      resource_string.string_translations.each do |string_translation|
        assert_equal REVIEW_NOT_NEEDED, string_translation.review_status
      end
    end

    # --- pay for the invoice ---

    txn = 'PP9875'
    fee = total * 0.03

    # now, do the PayPal IPN for this payment
    tx = PaypalMockReply.new(payer_email: client.email,
                             first_name: client.fname,
                             last_name: client.lname)

    tx.save
    tx.update_attributes(txn_id: txn,
                         business: Figaro.env.PAYPAL_BUSINESS_EMAIL,
                         mc_gross: total,
                         mc_currency: 'USD',
                         mc_fee: fee,
                         payment_status: 'Completed',
                         payer_status: 'verified',
                         invoice: invoice.id,
                         txn_type: 'web_accept')

    post(url_for(controller: :finance, action: :paypal_ipn), tx.attributes)
    assert_response :success
    assert_nil assigns['retry']
    assert_nil assigns['errors']

    invoice.reload

    assert_equal invoice.status, TXN_COMPLETED
    assert_equal invoice.txn, txn

    # no reviewers yet, so no email to deliver. only payment confirmation to the client
    check_emails_delivered(1)

    # check that all the strings went to translation
    text_resource.resource_strings.each do |resource_string|
      resource_string.string_translations.each do |string_translation|
        string_translation.reload
        assert_equal REVIEW_AFTER_TRANSLATION, string_translation.review_status
      end
    end

    # check that the resource language balances include the payment
    text_resource.resource_languages.each do |resource_language|
      resource_language_account = resource_language.money_accounts[0]
      resource_language_account.reload
      assert_same_amount (word_count * resource_language.translation_amount * 0.5 * 3), resource_language_account.balance
      assert_equal word_count, resource_language.selected_chat.word_count
      resource_language.resource_chats.each do |resource_chat|
        # word count for translation doesn't change
        counted_words = resource_chat.real_word_count
        assert_equal resource_chat.word_count, counted_words
      end
    end
    # Todo Investigate this failing paypal test - jon 02162017
    # test that the user sees a good 'thank you' page after payment
    # post(url_for(controller: :finance, action: :paypal_complete), tx: tx.txn_id)
    # assert_response :success

    # visit the invoice page
    get(url_for(controller: :finance, action: :invoice, id: invoice.id))
    assert_response :success

    # visit the project page
    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    logout(session)

  end

  def test_payment_together
    init_email_deliveries

    delete_all

    checker = PeriodicChecker.new(Time.now)
    cnt = checker.per_profile_mailer
    assert_equal 0, cnt
    check_emails_delivered(0)

    client = users(:amir)

    session = login(client)

    get(url_for(controller: :text_resources, action: :index))
    assert_response :success

    get(url_for(controller: :text_resources, action: :new))
    assert_response :success

    # --- create the project ---
    language = languages(:English)
    name = 'Test proj'
    description = 'this is what it is about'

    text_resource_count = TextResource.count

    post(url_for(controller: :text_resources, action: :create), text_resource: { name: name, description: description, language_id: language.id })
    assert_response :redirect

    assert_equal text_resource_count + 1, TextResource.count

    text_resource = TextResource.all.to_a[-1]
    assert_equal text_resource.name, name
    assert_equal text_resource.description, description
    assert_equal text_resource.language, language

    # **** in this test, we first upload the strings and then select the translation languages ****

    # --- upload the project ---

    resource_format = ResourceFormat.where('name=?', 'Delphi').first
    assert resource_format

    resource_upload_count = ResourceUpload.count

    # upload again, now accept
    fdata = fixture_file_upload('char_conversion/delphi_very_short.txt', 'application/octet-stream')
    multipart_post(url_for(controller: :resource_uploads, action: :create, text_resource_id: text_resource.id),
                   resource_upload: { uploaded_data: fdata }, resource_format_id: resource_format.id)
    assert_response :success

    assert_equal resource_upload_count + 1, ResourceUpload.count

    resource_upload = ResourceUpload.all.to_a[-1]
    assert_nil resource_upload.normal_user

    resource_strings = assigns(:resource_strings)
    post(url_for(controller: :resource_uploads, action: :scan_resource, text_resource_id: text_resource.id, id: resource_upload.id), string_idx_param(resource_strings))
    assert_response :redirect

    text_resource.reload

    assert_equal 3, text_resource.resource_strings.length

    # --- choose translation languages ---
    xml_http_request(:post, url_for(controller: :text_resources, action: :edit_languages, id: text_resource.id, format: :js), req: 'show')
    assert_response :success

    assert assigns(:show_edit_languages)
    assert assigns(:languages)

    languages = assigns(:languages)
    assert languages.length >= 2, 'not enough translation languages'

    to_language_dic = {}
    to_languages = [languages(:Spanish), languages(:German)]
    to_languages.each do |tl|
      assert languages.key?(tl.name)
      to_language_dic[tl.id] = 1
    end

    post(url_for(controller: :text_resources, action: :edit_languages, id: text_resource.id, format: :js),
         req: 'save', language: to_language_dic)
    assert_response :redirect

    text_resource.reload
    assert_equal to_languages.length, text_resource.resource_languages.length

    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    # --- see that translators are notified now ---
    cnt = checker.per_profile_mailer
    assert_not_equal 0, cnt
    check_emails_delivered(cnt)

    logout(session)

    # --- log in as translator and apply for the two jobs ---
    translator = users(:orit)
    session = login(translator)

    get(url_for(controller: :translator, action: :open_work))
    assert_response :success

    open_text_resource_projects = assigns(:open_text_resource_projects)
    assert open_text_resource_projects
    assert_equal to_languages.length, open_text_resource_projects.length

    # --- view the project ---
    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    open_text_resource_projects.each do |resource_language|
      get(url_for(controller: :resource_chats, action: :new, text_resource_id: text_resource.id, resource_lang_id: resource_language.id))
      assert_response :success

      resource_chats_count = text_resource.resource_chats.count

      # apply for this job
      post(url_for(controller: :resource_chats, action: :create, text_resource_id: text_resource.id),
           resource_chat: { resource_language_id: resource_language.id }, message: 'hello', apply: 1)
      assert_response :redirect

      text_resource.reload
      assert_equal resource_chats_count + 1, text_resource.resource_chats.count
      resource_chat = text_resource.resource_chats[-1]

      assert_equal translator, resource_chat.translator
      assert_equal RESOURCE_CHAT_APPLIED, resource_chat.status
      assert_equal 1, resource_chat.messages.length

      check_emails_delivered(1)
    end

    logout(session)

    # --- accept the applications ---
    session = login(client)

    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    assert_equal to_languages.length, text_resource.resource_chats.length

    text_resource.resource_chats.each do |resource_chat|
      get(url_for(controller: :resource_chats, action: :show, text_resource_id: text_resource.id, id: resource_chat.id))
      assert_response :success

      post(url_for(controller: :resource_chats, action: :update_application_status, text_resource_id: text_resource.id, id: resource_chat.id),
           status: RESOURCE_CHAT_ACCEPTED)
      assert_response :redirect

      check_emails_delivered(1)

      resource_chat.reload
      assert_equal RESOURCE_CHAT_ACCEPTED, resource_chat.status

      # also, send a message
      post(url_for(controller: :resource_chats, action: :create_message, text_resource_id: text_resource.id, id: resource_chat.id, format: :js),
           body: 'this is what I want to say', max_idx: 1, for_who1: translator.id)
      assert_response :success

      resource_chat.reload
      assert_equal 2, resource_chat.messages.length

      check_emails_delivered(1)

    end

    # --- create an invoice for this job ---

    # ZERO the clients account so that payment is required
    client_account = client.find_or_create_account(DEFAULT_CURRENCY_ID)
    client_account.balance = 0
    client_account.save

    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    assert_select 'div#missing_funds'

    invoices_count = client.invoices.count

    # construct the post
    args = {}
    text_resource.resource_languages.each do |resource_language|
      args["resource_language#{resource_language.id}"] = 1
      args["transaction_code#{resource_language.id}"] = TRANSFER_DEPOSIT_TO_RESOURCE_TRANSLATION_WITH_REVIEW
    end

    post(url_for(controller: :text_resources, action: :deposit_payment, id: text_resource.id), args)
    assert_response :redirect

    assert_equal invoices_count + 1, client.invoices.count
    invoice = client.invoices[-1]

    # check the total
    word_count = text_resource.count_words(text_resource.resource_strings, language, nil)
    total = text_resource.resource_languages.inject(0) { |a, b| a + b.cost }
    total = total.ceil_money
    assert_same_amount(total, invoice.gross_amount)

    # check that we have the right number of money trasactions
    # one for deposit other for tax
    assert_equal text_resource.resource_languages.count + 2, invoice.money_transactions.count

    rl_transfers = 0
    invoice.money_transactions.each do |money_transaction|
      if money_transaction.target_account.class == UserAccount
        assert_same_amount(money_transaction.amount, total)
      elsif money_transaction.target_account.class == ResourceLanguageAccount
        assert_same_amount(money_transaction.amount, money_transaction.target_account.resource_language.translation_amount * 1.5 * word_count)
        rl_transfers += 1
      elsif money_transaction.target_account.class == TaxAccount
        # we are not setting taxes
        assert_same_amount(money_transaction.amount, 0)
      else
        assert false
      end
    end

    assert_equal text_resource.resource_languages.count, rl_transfers

    # before payment, all the translation should be missing
    text_resource.resource_strings.each do |resource_string|
      resource_string.string_translations.each do |string_translation|
        assert_equal STRING_TRANSLATION_MISSING, string_translation.status
      end
    end

    # --- pay for the invoice ---

    txn = 'PP9876'
    fee = total * 0.03

    # now, do the PayPal IPN for this payment
    tx = PaypalMockReply.new(payer_email: client.email,
                             first_name: client.fname,
                             last_name: client.lname)

    tx.save
    tx.update_attributes(txn_id: txn,
                         business: Figaro.env.PAYPAL_BUSINESS_EMAIL,
                         mc_gross: total,
                         mc_currency: 'USD',
                         mc_fee: fee,
                         payment_status: 'Completed',
                         payer_status: 'verified',
                         invoice: invoice.id,
                         txn_type: 'web_accept')

    post(url_for(controller: :finance, action: :paypal_ipn), tx.attributes)
    assert_response :success
    assert_nil assigns['retry']
    assert_nil assigns['errors']

    invoice.reload

    assert_equal invoice.status, TXN_COMPLETED
    assert_equal invoice.txn, txn

    # the translators should have received start-work emails
    check_emails_delivered(text_resource.resource_languages.count + 1)

    # check that all the strings went to translation
    text_resource.resource_strings.each do |resource_string|
      resource_string.string_translations.each do |string_translation|
        string_translation.reload
        assert_equal STRING_TRANSLATION_BEING_TRANSLATED, string_translation.status
      end
    end

    # check that the resource language balances include the payment
    text_resource.resource_languages.each do |resource_language|
      resource_language_account = resource_language.money_accounts[0]
      assert_same_amount resource_language.translation_amount * 1.5 * word_count, resource_language_account.balance
      resource_language.selected_chat.reload
      assert_equal word_count, resource_language.selected_chat.word_count
      resource_language.resource_chats.each do |resource_chat|
        counted_words = resource_chat.real_word_count
        assert_equal resource_chat.word_count, counted_words
      end
    end
    # Todo Investigate this failing paypal test - jon 02162017
    # test that the user sees a good 'thank you' page after payment
    # post(url_for(controller: :finance, action: :paypal_complete), tx: tx.txn_id)
    # assert_response :success

    # visit the invoice page
    get(url_for(controller: :finance, action: :invoice, id: invoice.id))
    assert_response :success

    # visit the project page
    get(url_for(controller: :text_resources, action: :show, id: text_resource.id))
    assert_response :success

    # --- send the strings to review too ---

    # all the translation should be waiting
    text_resource.resource_strings.each do |resource_string|
      resource_string.string_translations.each do |string_translation|
        assert_equal REVIEW_AFTER_TRANSLATION, string_translation.review_status
      end
    end

  end

  def delete_all
    TextResource.delete_all
    ResourceLanguage.delete_all
    ResourceChat.delete_all
    ResourceString.delete_all
    StringTranslation.delete_all
    ManagedWork.delete_all
    Website.delete_all
    WebsiteTranslationOffer.delete_all
    WebsiteTranslationContract.delete_all
    SentNotification.delete_all
  end

  def string_idx_param(resource_strings)
    if resource_strings.first.is_a? ResourceString
      { 'string_token' => resource_strings.map { |x| Digest::MD5.hexdigest(x.token) } }
    else
      { 'string_token' => resource_strings.map { |x| Digest::MD5.hexdigest(x[:token]) } }
    end
  end

end
