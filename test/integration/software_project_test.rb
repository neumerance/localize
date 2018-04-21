require "#{File.dirname(__FILE__)}/../test_helper"

class SoftwareProjectTest < ActionDispatch::IntegrationTest
  fixtures :all

  # Tests a complete project cycle for a default client.
  def test_client_std_lifecycle
    std_project_lifecycle(:amir)
  end

  # Test a complete project cycle for an alias from the client
  # with full access to modify, pay, and anything else needed.
  def test_alias_full_std_lifecycle
    std_project_lifecycle(:alias_full)
  end

  def std_project_lifecycle(client_name)
    # Grab the main actors
    @client = users(client_name)
    @translator = users(:orit)
    @reviewer = users(:guy)

    # This aliases will be used eventually to make sure they can't access the proper areas
    @alias_cant_do = users(:alias_cant_do) # This alias has no access permissions
    @alias_cant_edit = users(:alias_cant_edit)
    @alias_cant_pay = users(:alias_cant_pay)
    @alias_can_pay = users(:alias_can_pay)

    login(@client)

    # Periodic checker setup
    checker = PeriodicChecker.new(Time.now)

    # Create the project
    text_resource = create_project

    # Edit the status of the project
    edit_project(text_resource)

    # Add two languages: Spanish and French
    add_languages(text_resource)

    # Disable review from both languages
    disable_review(text_resource)

    # Enable review from spanish only
    enable_review(text_resource)

    # Upload a simple file
    upload_file(text_resource)

    # Check if the translators were notified
    check_notifications(checker, 4)

    # invite translators to do the translations
    invite_translators(text_resource)

    # Translator apply to both languages
    login(@translator)
    apply_to_project(@translator, text_resource)

    # Translator becomes reviewer for french
    login(@reviewer)
    become_manager(@reviewer, text_resource)

    # Accept applications
    login(@client)
    accept_applications(text_resource)

    # Send texts to translate without money
    @client.money_accounts.first.update_attributes(balance: 0)
    send_to_translate_without_money(text_resource)

    # Sends text to translate with money
    @client.money_accounts.first.update_attributes(balance: 99999)
    send_to_translate(@client, text_resource)

    # Translate every string from the project
    login(@translator)
    do_translations(text_resource)

    # Click on "complete the translation" button
    deliver_work(text_resource)

    # As client, download the translations
    login(@client)
    download_translations(text_resource)

    # Do the review
    login(@reviewer)
    review(text_resource)

    # Download final version
    login(@client)
    download_translations(text_resource)
  end

  def create_project
    # home
    get('/client')
    assert_response :success, "Can't get client home page"

    # new
    get(new_text_resource_url)
    assert_response :success, "Can't get new text resource page"

    # test alias access
    login(@alias_cant_do)
    get(new_text_resource_url)
    assert_response :redirect, 'Alias without permissions can see this page'
    login(@alias_cant_edit)
    get(new_text_resource_url)
    assert_response :redirect, "Alias can edit but can't create new projects"
    login(@client)

    # create
    language = languages(:English)
    name = 'Test proj'
    description = 'this is what it is about'
    assert_difference('TextResource.count', 1, 'Failed creating project') do
      post url_for(controller: :text_resources, action: :create), params: { text_resource: { name: name, description: description, language_id: language.id } }
      assert_response :redirect, "Can't create project"
    end

    # validation
    text_resource = TextResource.last
    assert_equal text_resource.name, name
    assert_equal text_resource.description, description
    assert_equal text_resource.language, language

    # show
    get text_resource_url(text_resource.id)
    assert_response :success, "Can't view software project page"

    # test alias access
    login(@alias_cant_do)
    get text_resource_url(text_resource.id)
    assert_response :redirect, 'Alias without permissions can see this page'
    login(@alias_cant_edit)
    get text_resource_url(text_resource.id)
    assert_response :success, "Alias with permissions can't see this page"
    login(@client)

    text_resource
  end

  def edit_project(text_resource)
    # show
    get text_resource_url(text_resource.id)
    assert_response :success, "Can't view software project page"

    # enable edit screen
    get(edit_description_text_resource_url(text_resource.id))
    assert_response :success, "Can't start editing text resource settings"

    # edit attributes
    new_name = 'new_name'
    new_description = 'new description for this project'
    new_required_text = 'new required text'
    new_category_id = 2

    put(text_resource_url(text_resource.id), params: {
          text_resource: { name: new_name, description: new_description, required_text: new_required_text, category_id: new_category_id }
        })

    assert_response :redirect
    assert_equal 'Project updated', flash[:notice]

    text_resource.reload
    assert_equal new_name, text_resource.name, 'Failed to edit name'
    assert_equal new_description, text_resource.description, 'Failed to edit description'
    assert_equal new_required_text, text_resource.required_text, 'Failed to edit required text'
    assert_equal new_category_id, text_resource.category_id, 'Failed to edit category id'

    # test alias access
    login(@alias_cant_do)
    put(text_resource_url(text_resource.id), params: {
          text_resource: { name: new_name, description: new_description, required_text: new_required_text, category_id: new_category_id }
        })
    assert_response :redirect
    assert_not_equal 'Project updated', flash[:notice]
    login(@alias_cant_edit)
    put(text_resource_url(text_resource.id), params: {
          text_resource: { name: new_name, description: new_description, required_text: new_required_text, category_id: new_category_id }
        })
    assert_response :redirect
    assert_not_equal 'Project updated', flash[:notice]
    login(@client)
  end

  def add_languages(text_resource)
    # show
    get text_resource_url(text_resource.id)
    assert_response :success, "Can't view software project page"

    # test alias access
    login(@alias_cant_do)
    get text_resource_url(text_resource.id)
    assert_response :redirect, 'Alias without permissions can see this page'
    login(@alias_cant_edit)
    get text_resource_url(text_resource.id)
    assert_response :success, "Alias with permissions can't see this page"
    login(@client)

    # test alias access
    login(@alias_cant_do)
    post edit_languages_text_resource_url(text_resource.id), params: { req: 'show' }
    assert_response :redirect
    assert_nil assigns(:show_edit_languages)
    login(@alias_cant_edit)
    post edit_languages_text_resource_url(text_resource.id, format: :js), params: { req: 'show' }
    assert_response :success
    assert assigns(:show_edit_languages)
    login(@client)

    # edit
    post edit_languages_text_resource_url(text_resource.id, format: :js), params: { req: 'show' }
    assert_response :success, "Can't view edit languages boxes"
    assert assigns(:show_edit_languages)
    assert assigns(:languages).any?

    # TODO: Move to functional?
    languages = assigns(:languages)
    assert languages.length >= 2, 'not enough translation languages'

    # test alias access
    login(@alias_cant_do)
    post edit_languages_text_resource_url(text_resource.id), params: { req: 'save', language: { 3 => 1, 5 => 1 } }
    assert_response :redirect
    text_resource.reload
    assert text_resource.resource_languages.empty?
    login(@alias_cant_edit)
    post edit_languages_text_resource_url(text_resource.id), params: { req: 'save', language: { 3 => 1, 5 => 1 } }
    assert_response :redirect
    text_resource.resource_languages.each do |rl|
      assert rl.language
      assert [3, 5].include?(rl.language_id), 'Language was not saved after being added'
      assert rl.managed_work, "This resource language don't have a managed work"
      assert_equal MANAGED_WORK_ACTIVE, rl.managed_work.active, 'Managed work is not active by default'
    end
    login(@client)

    # update (to spanish and french)
    post edit_languages_text_resource_url(text_resource.id, format: :js), params: { req: 'save', language: { 2 => 1, 4 => 1 } }
    assert_response :redirect, 'fail to save added languages'
    text_resource.reload
    text_resource.resource_languages.each do |rl|
      assert rl.language
      assert [2, 4].include?(rl.language_id), 'Language was not saved after being added'
      assert rl.managed_work, "This resource language don't have a managed work"
      assert_equal MANAGED_WORK_ACTIVE, rl.managed_work.active, 'Managed work is not active by default'
    end
    assert text_resource.resource_languages.uniq.size == 2, 'Wrong number of languages after add new one'
  end

  def disable_review(text_resource)
    # show
    get text_resource_url(text_resource.id)
    assert_response :success, "Can't view software project page"

    # test alias access
    login(@alias_cant_do)
    get text_resource_url(text_resource.id)
    assert_response :redirect, 'Alias without permissions can see this page'
    login(@alias_cant_edit)
    get text_resource_url(text_resource.id)
    assert_response :success, "Alias with permissions can't see this page"
    login(@client)

    # test alias access first
    [@alias_cant_do, @alias_cant_edit].each do |user|
      login(user)
      text_resource.resource_languages.each do |rl|
        managed_work = rl.managed_work
        post update_status_managed_work_url(managed_work.id, format: :js), params: { active: MANAGED_WORK_INACTIVE }
        managed_work.reload
        assert_not_equal MANAGED_WORK_INACTIVE, managed_work.active, "Review status didn't changed"
      end
    end
    login(@client)

    # Disable review of both languages
    text_resource.resource_languages.each do |rl|
      managed_work = rl.managed_work
      post update_status_managed_work_url(managed_work.id, format: :js), params: { active: MANAGED_WORK_INACTIVE }
      assert_response :success, 'Failed to disable review'
      managed_work.reload
      assert_equal MANAGED_WORK_INACTIVE, managed_work.active, "Review status didn't changed"
    end

  end

  def enable_review(text_resource)
    # show
    get text_resource_url(text_resource.id)
    assert_response :success, "Can't view software project page"

    # test alias access
    login(@alias_cant_do)
    get text_resource_url(text_resource.id)
    assert_response :redirect, 'Alias without permissions can see this page'
    login(@alias_cant_edit)
    get text_resource_url(text_resource.id)
    assert_response :success, "Alias with permissions can't see this page"
    login(@client)

    # test alias access first
    [@alias_cant_do, @alias_cant_edit].each do |user|
      login(user)
      managed_work = text_resource.resource_languages.first.managed_work
      post update_status_managed_work_url(managed_work.id), params: { active: MANAGED_WORK_ACTIVE }
      assert_response :redirect
      managed_work.reload
      assert_not_equal MANAGED_WORK_ACTIVE, managed_work.active, "Review status didn't changed"
    end
    login(@client)

    # enable review from the first language; the second one should be kept disabled
    managed_work = text_resource.resource_languages.first.managed_work
    post update_status_managed_work_url(managed_work.id, format: :js), params: { active: MANAGED_WORK_ACTIVE }
    assert_response :success, 'Failed to disable review'
    managed_work.reload
    assert_equal MANAGED_WORK_ACTIVE, managed_work.active, "Review status didn't changed"
  end

  def check_notifications(checker, expected_notifications)
    assert_difference('ActionMailer::Base.deliveries.length', expected_notifications, 'Wrong number of e-mails reported by per_profile_mailer') do
      cnt = checker.per_profile_mailer
      assert_equal cnt, expected_notifications, 'Per profiler mailer is returning the wrong number of notifications sent'
    end

    assert_no_difference('ActionMailer::Base.deliveries.length', 'Cheker sent e-mail sent more than one time') do
      cnt = checker.per_profile_mailer
      assert_equal 0, cnt, "per_profile_mailer didn't return the expected"
    end
  end

  def upload_file(text_resource)
    # show
    get text_resource_url(text_resource.id)
    assert_response :success, "Can't view software project page"

    # test alias access
    login(@alias_cant_do)
    get text_resource_url(text_resource.id)
    assert_response :redirect, 'Alias without permissions can see this page'
    login(@alias_cant_edit)
    get text_resource_url(text_resource.id)
    assert_response :success, "Alias with permissions can't see this page"
    login(@client)

    # prepare file
    resource_format = ResourceFormat.where('name=?', 'Delphi').first
    assert resource_format
    fdata = fixture_file_upload('files/delphi_very_short.txt', 'application/octet-stream')

    # Test aliases can't upload
    [@alias_cant_do, @alias_cant_edit].each do |user|
      login(user)
      resource_upload_count = ResourceUpload.count
      assert_no_difference('ResourceUpload.count') do
        multipart_post(text_resource_resource_uploads_url(text_resource.id), resource_upload: { uploaded_data: fdata },
                                                                             resource_format_id: resource_format.id)
        assert_response :redirect
      end
      assert_nil assigns(:resource_strings)
      assert_equal 0, resource_strings.length
    end
    login(@client)

    # Upload file
    resource_upload_count = ResourceUpload.count
    assert_difference('ResourceUpload.count', 1, 'Resource upload model not created after post') do
      multipart_post(text_resource_resource_uploads_url(text_resource.id), resource_upload: { uploaded_data: fdata },
                                                                           resource_format_id: resource_format.id)
      assert_response :success, 'failed to create the resource upload'
    end
    resource_strings = assigns(:resource_strings)
    assert resource_strings
    assert_equal 3, resource_strings.length

    # cancel this upload
    resource_upload = ResourceUpload.last
    assert_difference('ResourceUpload.count', -1, 'Resource upload not destroyed after delete') do
      delete(text_resource_resource_upload_url(text_resource.id, resource_upload.id))
      assert_response :redirect
    end
    assert_equal 0, text_resource.resource_strings.count, 'Added the strings after cancel on the confirmation screen'

    # Upload again
    resource_upload_count = ResourceUpload.count
    assert_difference('ResourceUpload.count', 1, 'Resource upload model not created after post') do
      multipart_post(text_resource_resource_uploads_url(text_resource.id), resource_upload: { uploaded_data: fdata },
                                                                           resource_format_id: resource_format.id)
      assert_response :success, 'failed to create the resource upload'
    end
    resource_strings = assigns(:resource_strings)
    assert resource_strings
    assert_equal 3, resource_strings.length

    # Accept
    resource_upload = ResourceUpload.last
    assert_no_difference('ResourceUpload.count', 'Resource upload model not created after post') do
      post scan_resource_text_resource_resource_upload_url(text_resource.id, resource_upload.id),
           params: { string_token: resource_strings.map { |x| Digest::MD5.hexdigest(x[:token]) } }
      assert_response :redirect, 'Failed accepting the strings'
    end
    text_resource.reload
    assert_equal 3, text_resource.resource_strings.count, "Didn't added the strings"
  end

  def invite_translators(text_resource)
    # test alias access
    login(@alias_cant_do)
    get text_resource_url(text_resource.id)
    assert_response :redirect, 'Alias without permissions can see this page'
    login(@alias_cant_edit)
    get text_resource_url(text_resource.id)
    assert_response :success, "Alias with permissions can't see this page"
    assert_select('a#invite_translators', { count: 0 }, 'Alias that cant edit can see the invite button')
    login(@client)

    # show
    get text_resource_url(text_resource.id)
    assert_response :success, "Can't view software project page"

    # for each language, invite a translator
    tag = assert_select('a#invite_translators', { count: text_resource.resource_languages.size }, 'Could not find a invite button').last
    resource_language = text_resource.resource_languages.last

    # Get into the translators list
    get(tag['href'])
    assert_response :success, 'Could not get to the translators list while inviting'

    # Preparete our translator
    orit = users(:orit)
    orit_link = assert_select('a', { count: 1, text: orit.nickname }, 'Could not find orit in the translators list to invite').first['href']

    # Can't edit can't see the invite button
    login(@alias_cant_edit)
    get(orit_link)
    assert_response :success, 'Could not visualize translator home while inviting'
    assert_select('a', { text: text_resource['name'], count: 0 }, "Button to invite should not be found for alias that can't edit")
    login(@client)

    # visit orit profile
    get(orit_link)
    assert_response :success, 'Could not visualize translator home while inviting'
    assert_select('a', { text: text_resource['name'] }, 'Could not find reference to text resource')

    # Click on "write invitation"
    post invite_to_job_user_url(orit[:id], format: :js), params: { req: 'show', job_class: 'ResourceLanguage', job_id: resource_language[:id], user_ud: orit[:id], div: "inviteResourceLanguage#{resource_language[:id]}" }
    assert_response :success, 'Could not start writting an invitation'

    # alias can't send an invitation
    [@alias_cant_do, @alias_cant_edit].each do |user|
      login(user)
      message = 'Join us in this project'
      assert_no_difference('ActionMailer::Base.deliveries.length', 1) do
        post invite_to_job_user_url(orit[:id]), params: { message: message, div: "inviteResourceLanguage#{resource_language[:id]}", job_class: 'ResourceLanguage', job_id: resource_language[:id] }
        assert_response :redirect, 'Can invite translator when should not'
      end
    end
    login(@client)

    # Send an invitation
    message = 'Join us in this project'
    assert_difference('ActionMailer::Base.deliveries.length', 1, "Didn't alert transaltor from new invitation") do
      post invite_to_job_user_url(orit[:id], format: :js), params: { message: message, div: "inviteResourceLanguage#{resource_language[:id]}", job_class: 'ResourceLanguage', job_id: resource_language[:id] }
      assert_response :success, 'Could not invite translator'
    end
  end

  def apply_to_project(_translator, text_resource)
    # translator home page
    get('/translator')
    assert_response :success, 'Could not visualize the translator home page'

    text_resource.resource_languages.each_with_index do |resource_language, i|
      # The first one he was not invited, so should appear on open work
      if i == 0
        # open_work
        get('/translator/open_work')
        assert_response :success, "Couldn't view open work page"
        assert_select 'a', { text: text_resource.name }, 'Text resource is not available'

        # show project
        get text_resource_url(text_resource.id)
        assert_response :success, "Can't view software project page"

        # show project
        get text_resource_url(text_resource.id)
        assert_response :success, "Can't view software project page"
        assert_select 'a', { text: 'Apply for this work' }, "Can't find button to apply to work"

        # new resource chat
        get new_text_resource_resource_chat_url(text_resource.id), params: { resource_lang_id: resource_language.id }
        assert_response :success, "Can't view new chat screen"

        # Apply to the work
        message = 'I would like to work with you'
        apply = 1
        rc_rl_id = resource_language.id
        post text_resource_resource_chats_url(text_resource.id), params: { message: message, apply: 1, resource_chat: { resource_language_id: rc_rl_id } }
        assert_response :redirect, "Can't apply to the work/create the resource chat"
        resource_language.reload
        resource_chat = resource_language.resource_chats.first
        assert_equal 1, resource_chat.messages.size
        assert_equal RESOURCE_CHAT_APPLIED, resource_chat.status
      # The last one he was invited, so should be accessible through the reminders
      else
        resource_chat = resource_language.resource_chats.first
        # translator home page
        get('/translator')
        assert_response :success, 'Could not visualize the translator home page'
        assert_select 'a', { href: "/text_resources/#{text_resource['id']}/resource_chats/#{resource_chat.id}" }, 'Could not find message on reminders'

        # See the client invitation message
        get(text_resource_resource_chat_url(text_resource.id, resource_chat.id))
        assert_response :success, "Can't view the client invitation"

        # Apply to the work
        post update_application_status_text_resource_resource_chat_url(text_resource.id, resource_chat.id), params: { status: 1 }
        assert_response :redirect, 'Failed to apply to work'
        assert_nil assigns(:notice), 'notice should be empty after applying to work'
        resource_chat.reload
        assert_equal RESOURCE_CHAT_APPLIED, resource_chat.status, 'Inconsitent value to chat status after apply to work'
      end
      # see the chat again
      get(text_resource_resource_chat_url(text_resource.id, resource_chat.id))
      assert_response :success, "Can't view the resource chat screen"
    end
  end

  def become_manager(translator, text_resource)
    managed_work = text_resource.resource_languages.first.managed_work

    # translator home page
    get('/translator')
    assert_response :success, 'Could not visualize the translator home page'

    # show project
    get text_resource_url(text_resource.id)
    assert_response :success, "Can't view software project page"
    assert_select('a', { text: 'Become the reviewer for this job', count: 1 }, "Can't find the button to become reviewer, or have more than one")

    # Click in become reviewer
    post(be_reviewer_managed_work_url(managed_work.id))
    assert_response :redirect, 'System failure clicking in become reviewer button'
    managed_work.reload
    assert_equal translator.id, managed_work.translator_id, 'Failed to become reviewer'
  end

  def accept_applications(text_resource)
    # show
    get text_resource_url(text_resource.id)
    assert_response :success, "Can't view software project page"

    # test alias access
    login(@alias_cant_do)
    get text_resource_url(text_resource.id)
    assert_response :redirect, 'Alias without permissions can see this page'
    login(@alias_cant_edit)
    get text_resource_url(text_resource.id)
    assert_response :success, "Alias with permissions can't see this page"
    login(@client)

    text_resource.resource_chats.each do |resource_chat|
      # test alias access
      login(@alias_cant_do)
      get(text_resource_resource_chat_url(text_resource.id, resource_chat.id))
      assert_response :redirect, 'Alias without permissions can see this page'
      login(@alias_cant_edit)
      get(text_resource_resource_chat_url(text_resource.id, resource_chat.id))
      assert_response :success, "Alias with permissions can't see this page"
      login(@client)

      # show the chat
      get(text_resource_resource_chat_url(text_resource.id, resource_chat.id))
      assert_response :success, "Couldn't see the chat"

      # alias can't accept
      [@alias_cant_do, @alias_cant_edit].each do |user|
        login user
        post update_application_status_text_resource_resource_chat_url(text_resource.id, resource_chat.id), params: { status: RESOURCE_CHAT_ACCEPTED }
        assert_response :redirect, "Couldn't accept the application"
        resource_chat.reload
        assert_not_equal RESOURCE_CHAT_ACCEPTED, resource_chat.status, "Status from resource chat didn't changed"
      end
      login @client

      # click in accept
      assert_difference('ActionMailer::Base.deliveries.length', 1, "Didn't alert transaltor for accepted application") do
        # client can accept
        post update_application_status_text_resource_resource_chat_url(text_resource.id, resource_chat.id), params: { status: RESOURCE_CHAT_ACCEPTED }
        assert_response :redirect, "Couldn't accept the application"
        resource_chat.reload
        assert_equal RESOURCE_CHAT_ACCEPTED, resource_chat.status, "Status from resource chat didn't changed"
      end
    end
  end

  def send_to_translate_without_money(text_resource)
    # show
    get text_resource_url(text_resource.id)
    assert_response :success, "Can't view software project page"
    assert_select 'h3', { text: 'Missing Funding' }, "Was not notified that don't have money"

    # test alias access
    login(@alias_cant_do)
    get text_resource_url(text_resource.id)
    assert_response :redirect, 'Alias without permissions can see this page'
    login(@alias_cant_edit)
    get text_resource_url(text_resource.id)
    assert_response :success, "Alias with permissions can't see this page"
    assert_select 'input#pay', value: 'Pay with PayPal', count: 0
    login(@alias_can_pay)
    get text_resource_url(text_resource.id)
    assert_response :success, "Alias with permissions can't see this page"
    assert_select 'input#pay', value: 'Pay with PayPal', count: 1
    login(@client)
  end

  def send_to_translate(client, text_resource)
    # show
    get text_resource_url(text_resource.id)
    assert_response :success, "Can't view software project page"
    assert_select 'h3', { text: 'Missing Funding', count: 0 }, "Showing missing funding when shouldn't"

    # test alias access
    login(@alias_cant_do)
    get text_resource_url(text_resource.id)
    assert_response :redirect, 'Alias without permissions can see this page'
    login(@alias_cant_edit)
    get text_resource_url(text_resource.id)
    assert_response :success, "Alias with permissions can't see this page"
    login(@client)

    # Check all checkboxes and send strings to translation
    text_resource.resource_chats.each { |rc| assert_equal 0, rc.word_count }
    previous_balance = client.money_accounts.first.balance
    assert_difference('ActionMailer::Base.deliveries.length', text_resource.resource_chats.count, "Didn't alert all translators") do
      post start_translations_text_resource_resource_chats_url(text_resource.id), params: { selected_chats: text_resource.resource_chats.map(&:id) }
      assert_response :redirect
    end
    text_resource.resource_chats.each { |rc| rc.reload; assert_not_equal 0, rc.word_count }
    paid = previous_balance - client.money_accounts.first.balance
    assert paid > 0
    assert_same_amount(paid, text_resource.resource_languages.inject(0) { |a, b| a + b.money_accounts.first.balance })
  end

  def do_translations(text_resource)
    # home page
    get('/translator')
    assert_response :success, 'Could not visualize the translator home page'
    assert_select 'td a', { text: text_resource.name }, 'Could not find the text resource on translators page'

    # Go to project strings
    get(text_resource_resource_strings_url(text_resource.id))
    assert_response :success, 'Could not see the strings from the project'
    assert_select('a', { text: 'Next string to translate »', count: 1 }, 'Could not find a button to translate next string').first['href']

    text_resource.resource_strings.each do |resource_string|
      # Go to string page
      get(text_resource_resource_string_url(text_resource.id, resource_string.id))
      assert_response :success, 'Could not see the first string to translate'
      assert_select 'input', { value: 'Edit (Alt-E)' }, "Can't find the button to edit"

      [2, 4].each do |lang_id|
        # Click on edit
        post(edit_translation_text_resource_resource_string_url(text_resource.id, resource_string.id, lang_id: lang_id, format: :js))
        assert_response :success, 'server fail after click in edit button'

        # Save translation
        money_account = text_resource.resource_languages.find_by(language_id: lang_id).money_accounts.first
        previous_balance = money_account.balance
        translation_text = 'translation here'
        post(update_translation_text_resource_resource_string_url(text_resource.id, resource_string.id, lang_id: lang_id,
                                                                                                        string_translation: { txt: translation_text },
                                                                                                        complete_translation: 1,
                                                                                                        auto_edit_next: (lang_id == 4 ? 1 : nil),
                                                                                                        req: 'save',
                                                                                                        format: :js))

        assert_response :success, "Error while saving the translation. Response code: #{@response.status}"
        saved_translation = StringTranslation.find_by(resource_string_id: resource_string.id, language_id: lang_id)
        assert saved_translation, "Can't find saved string"
        assert_equal translation_text, saved_translation.txt, 'Failed to save the transalation'
        money_account.reload
        assert previous_balance > money_account.balance, "Resource language money account balance didn't changed"
      end
    end

    text_resource.string_translations.each do |string_translation|
      assert_equal string_translation.status, STRING_TRANSLATION_COMPLETE, 'Found a string that was not translated yet'
    end
  end

  def deliver_work(text_resource)
    # home page
    get('/translator')
    assert_response :success, 'Could not visualize the translator home page'
    assert_select 'td a', { text: text_resource.name }, 'Could not find the text resource on translators page'

    # go to project page
    get text_resource_url(text_resource.id)
    assert_response :success, "Can't view software project page"

    text_resource.resource_chats.each do |resource_chat|
      # Go to chat page
      get(url_for(controller: :resource_chats, action: :show, text_resource_id: text_resource.id, id: resource_chat.id))
      assert_response :success, 'Failed trying to visualize resource chat page'

      # Click in complete
      assert_difference('ActionMailer::Base.deliveries.length', 2, "Didn't sent mail to the client confirming end of translation") do
        post(url_for(controller: :resource_chats, action: :translation_complete, text_resource_id: text_resource.id, id: resource_chat.id))
      end
      assert_response :redirect, 'Failed trying to click on complete translation button'
      resource_chat.reload
      expected_status = resource_chat.resource_language.managed_work.active == 1 ? RESOURCE_CHAT_TRANSLATION_COMPLETE : RESOURCE_CHAT_TRANSLATOR_NEEDS_TO_REVIEW
    end
  end

  def download_translations(text_resource)
    # go to project page
    get text_resource_url(text_resource.id)
    assert_response :success, "Can't view software project page"

    # aliases can't create translations
    resource_upload = text_resource.resource_uploads.first
    [@alias_cant_do, @alias_cant_edit].each do |user|
      login user
      post(create_translations_text_resource_url(text_resource.id, resource_upload_id: resource_upload.id))
      assert_response :redirect
      assert "You can't create/update the translations", flash[:notice]
    end
    login @client

    # Create the translations
    post(create_translations_text_resource_url(text_resource.id, resource_upload_id: resource_upload.id))
    assert_response :redirect
    text_resource.reload
    assert_equal text_resource.resource_languages.length, text_resource.resource_downloads.length

    text_resource.resource_languages.map(&:language_id).each do |tl|
      # one file per language
      upload_translations = resource_upload.upload_translations.where(language_id: tl)
      assert_equal 1, upload_translations.length, 'More than one upload translation per language'
      upload_translation = upload_translations.first
      assert upload_translation, "Couldn't find the upload translation"
      resource_download = upload_translation.resource_download
      assert resource_download, "Can't find resource download for uploaded translatioN"

      # Assert it is all translated
      assert resource_download.resource_download_stat
      assert_equal 3, resource_download.resource_download_stat.total, 'Stats are wrong'
      assert_equal 3, resource_download.resource_download_stat.completed, 'Stats are wrong'

      # test alias access to download the file
      login(@alias_cant_do)
      get text_resource_url(text_resource.id)
      assert_response :redirect
      login(@alias_cant_edit)
      get text_resource_url(text_resource.id)
      get(text_resource_resource_download_url(text_resource.id, resource_download.id))
      assert_response :success
      assert_equal resource_download, assigns(:resource_download)
      login(@client)

      # Download the file
      get(text_resource_resource_download_url(text_resource.id, resource_download.id))
      assert_response :success
      assert_equal resource_download, assigns(:resource_download)
    end
  end

  def review(text_resource)
    resource_language = text_resource.resource_languages.first
    language = resource_language.language

    # home page
    get('/translator')
    assert_response :success, 'Could not visualize the translator home page'
    assert_select 'td a', { text: text_resource.name }, 'Could not find the text resource on translators page'
    assert_select 'h2', 'Reviews you need to complete', "Can't find review notice"
    assert_select 'ul li a', { href: text_resource_url(text_resource.id) }, 'Project not listed on the alert to review'

    # Project page
    get text_resource_url(text_resource.id)
    assert_response :success, "Can't view software project page"
    assert_select 'a', { text: "Next #{language.name} String to Review" }, "Can't find button to review next string"

    text_resource.resource_strings.each do |resource_string|
      translation = resource_string.string_translations.find_by(language_id: language.id)
      assert_equal REVIEW_PENDING_ALREADY_FUNDED, translation.review_status

      # Get to string page
      get(text_resource_resource_string_url(text_resource.id, resource_string.id))
      assert_response :success, "Can't see the string to review"
      assert_select 'input', { type: 'submit', value: 'Review completed' }, "Can't find review completed button"

      # Click in review completed
      money_account = resource_language.money_accounts.first
      previous_balance = money_account.balance
      post complete_review_text_resource_resource_string_url(text_resource.id, resource_string.id, format: :js), params: { lang_id: language.id }
      assert_response :success, 'Failed clicking in review button'
      # assert_select 'p', { text: 'Review status: Review complete' }, 'Failed in display that the review is complete'
      assert @response.body.include?('Review status: Review complete'), 'Failed in display that the review is complete'
      translation.reload
      assert_equal REVIEW_COMPLETED, translation.review_status, "Review status didn't changed to complete"
      money_account.reload
      assert previous_balance > money_account.balance, "Resource language money account balance didn't changed"
    end
  end
end
