require 'zlib'
require "#{File.dirname(__FILE__)}/../test_helper"

class BiddingProjectTest < ActionDispatch::IntegrationTest
  fixtures :users, :languages, :alias_profiles

  # Tests a complete project cycle for a default client.
  def test_client_std_lifecycle
    std_project_lifecycle(:amir)
  end

  # Tests payments being done from the project screen
  def test_client_std_lifecycle_pps
    std_project_lifecycle(:amir, :payment_project_screen)
  end

  # Test a complete project cycle for an alias from the client
  # with full access to modify, pay, and anything else needed.
  def test_alias_std_lifecycle
    std_project_lifecycle(:alias_full)
  end

  def std_project_lifecycle(client_name, payment_type = nil)
    # Grab the main actors
    @client = users(client_name)
    @translator = users(:orit)
    @reviewer = users(:guy)

    # This aliases will be used eventually to make sure they can't access the proper areas
    @alias_cant_do = users(:alias_cant_do) # This alias has no access permissions
    @alias_cant_edit = users(:alias_cant_edit)
    @alias_cant_pay = users(:alias_cant_pay)
    @alias_can_pay = users(:alias_can_pay)

    # Create the project
    login(@client)
    revision = create_project

    # Create a project, fill all forms, upload the file and release to translators
    setup_project(revision)

    # Translator applies for both jobs
    login(@translator)
    translator_apply(revision)

    login(@client)
    accept_applications(revision, payment_type)

    login(@translator)
    finish_translation(revision)

    login(@reviewer)
    became_reviewer(revision)
    do_review(revision)
  end

  def setup_project(revision)
    project = revision.project

    # go to revision page
    get(project_revision_url(project.id, revision.id))
    assert_response :success

    # test alias permissions
    login @alias_cant_do
    get(project_revision_url(project, revision))
    assert_response :redirect
    login @alias_cant_edit
    get(project_revision_url(project, revision))
    assert_response :success
    login @client

    upload_file(revision)
    edit_description(revision)
    set_language(revision)
    set_translation_languages(revision)
    enable_review(revision)
    set_conditions(revision)
    edit_required_fields(revision)
    release_project(revision)
  end

  def create_project
    # first login page
    get('/client')
    assert_response :success
    assert_select 'a#start_new_project_button', count: 1

    # test if alias can see the button
    login @alias_cant_do
    get('/client')
    assert_response :success
    assert_select 'a#start_new_project_button', count: 0
    login @alias_cant_edit
    get('/client')
    assert_response :success
    assert_select 'a#start_new_project_button', count: 0
    login @client

    # getting_started page
    get('/client/getting_started')
    assert_response :success

    # alias cant get to gettting started page
    login @alias_cant_do
    get('/client/getting_started')
    assert_response :redirect
    login @alias_cant_edit
    get('/client/getting_started')
    assert_response :redirect
    login @client

    # Creating a office document project
    # Create new project screen
    get(new_project_url)
    assert_response :success

    # alias can't create the project
    name = 'Test project'
    kind = 1
    [@alias_cant_do, @alias_cant_edit].each do |user|
      login user
      assert_no_difference ['Project.count', 'Revision.count'] do
        post(projects_url, params: { project: { name: name, kind: kind } })
        assert_response :redirect
      end
    end
    login @client

    # Create the project
    assert_difference ['Project.count', 'Revision.count'], 1 do
      post(projects_url, params: { project: { name: name, kind: kind } })
      assert_response :redirect
    end
    project = Project.last
    revision = Revision.last
    assert_equal project, revision.project
    assert_equal project.name, name
    assert_equal project.kind, kind
    assert [@client, @client.master_account].include? project.client

    revision
  end

  def upload_file(revision)
    project = revision.project

    # go to revision page
    get(project_revision_url(project.id, revision.id))
    assert_response :success
    assert_select 'input#upload_file_button', count: 1

    # Click the upload file button

    post(edit_file_upload_project_revision_url(project, revision, format: :js), params: { req: :del })
    assert_response :success

    # alias can't see the upload file button
    login @alias_cant_edit
    get(project_revision_url(project, revision))
    assert_response :success
    assert_select 'input#upload_file_button', count: 0
    login @client

    # alias also can't upload a file
    login @alias_cant_edit
    # Uploads the file
    file = fixture_file_upload('files/iphone.txt', 'text/plain')
    assert_no_difference '::Version.count' do
      post(project_revision_versions_url(project, revision), params: { do_zip: 1, version: { uploaded_data: file } })
      assert_response :redirect
    end
    login @client

    # Uploads file
    assert_difference '::Version.count' do
      post(project_revision_versions_url(project, revision), params: { do_zip: 1, version: { uploaded_data: file } })
      assert_response :redirect
    end

    # Delete the uploaded file
    file = fixture_file_upload('files/iphone.txt', 'text/plain')
    assert_difference '::Version.count', -1 do
      post(edit_file_upload_project_revision_url(project, revision, format: :js), params: { req: :del })
      assert_response :success
    end

    # Uploads a file
    assert_difference '::Version.count' do
      post(project_revision_versions_url(project, revision), params: { do_zip: 1, version: { uploaded_data: file } })
      assert_response :redirect
    end
  end

  def edit_description(revision)
    project = revision.project

    # go to revision page
    get(project_revision_url(project.id, revision.id))
    assert_response :success
    assert_select 'input#edit_description_button', count: 1

    # Click the upload file button
    post(edit_description_project_revision_url(project, revision, format: :js), params: { req: :show })
    assert_response :success

    # alias can't see the upload file button
    login @alias_cant_edit
    get(project_revision_url(project, revision))
    assert_response :success
    assert_select 'input#edit_description_button', count: 0
    login @client

    # Alias can't edit the description too
    login @alias_cant_edit
    description = 'Some very interesting description'
    post(edit_description_project_revision_url(project, revision, format: :js), params: { req: :save,
                                                                                          revision: { description: description } })
    revision.reload
    assert_not_equal description, revision.description
    login @client

    # Edit the description
    post(edit_description_project_revision_url(project, revision, format: :js), params: { req: :save,
                                                                                          revision: { description: description } })
    assert_response :success
    revision.reload
    assert_equal description, revision.description
  end

  def set_language(revision)
    project = revision.project

    # go to revision page
    get(project_revision_url(project.id, revision.id))
    assert_response :success
    assert_select 'input#source_language_button', count: 1

    # Click the upload file button
    post(edit_source_language_project_revision_url(project, revision, format: :js), params: { req: :show })
    assert_response :success

    # alias can't see the upload file button
    login @alias_cant_edit
    get(project_revision_url(project, revision))
    assert_response :success
    assert_select 'input#source_language_button', count: 0
    login @client

    # Alias can't edit the language_id too
    login @alias_cant_edit
    language_id = 1
    post(edit_source_language_project_revision_url(project, revision, format: :js), params: { req: :save,
                                                                                              revision: { language_id: language_id } })
    revision.reload
    assert_not_equal language_id, revision.language_id
    login @client

    # Edit the language_id
    post(edit_source_language_project_revision_url(project, revision, format: :js), params: { req: :save,
                                                                                              revision: { language_id: language_id } })
    assert_response :success
    revision.reload
    assert_equal language_id, revision.language_id
  end

  def enable_review(revision)
    project = revision.project

    # alias can't see the disable review button
    login @alias_cant_edit
    get(project_revision_url(project, revision))
    assert_response :success
    assert_select 'a#disable_review', count: 0

    # client can see it
    login @client
    get(project_revision_url(project.id, revision.id))
    assert_response :success
    assert_select 'a#disable_review', count: 2

    # Click on disable review for both languages
    managed_work = revision.revision_languages.first.managed_work
    post(disable_managed_work_url(managed_work, format: :js), params: { active: 0 })
    managed_work.reload
    assert_equal MANAGED_WORK_INACTIVE, managed_work.active
    assert_response :success

    managed_work = revision.revision_languages.second.managed_work
    post(disable_managed_work_url(managed_work, format: :js), params: { active: 0 })
    managed_work.reload
    assert_equal MANAGED_WORK_INACTIVE, managed_work.active
    assert_response :success

    # Click on the enable review for the first language
    managed_work = revision.revision_languages.first.managed_work
    post(enable_managed_work_url(managed_work, format: :js), params: { active: 1 })
    managed_work.reload
    assert_equal MANAGED_WORK_PENDING_PAYMENT, managed_work.active
    assert_response :success
  end

  def set_translation_languages(revision)
    project = revision.project

    # go to revision page
    get(project_revision_url(project.id, revision.id))
    assert_response :success
    assert_select 'input#translation_languages_button', count: 1

    # Click the upload file button
    post(edit_languages_project_revision_url(project, revision, format: :js), params: { req: :show })
    assert_response :success

    # alias can't see the upload file button
    login @alias_cant_edit
    get(project_revision_url(project, revision))
    assert_response :success
    assert_select 'input#translation_languages_button', count: 0
    login @client

    # Alias can't edit the language_id too
    login @alias_cant_edit
    languages = [2, 4]
    languages_param = {}
    languages.each { |l| languages_param[l] = 1 }
    post(edit_languages_project_revision_url(project, revision, format: :js), params: { req: :save,
                                                                                        language: languages_param })
    revision.reload
    # assert revision.revision_languages.empty?
    login @client

    # Edit the language_id
    post(edit_languages_project_revision_url(project, revision, format: :js), params: { req: :save,
                                                                                        language: languages_param })
    assert_response :success
    revision.revision_languages.reload
    assert_equal languages, revision.revision_languages.map(&:language_id)
  end

  def set_conditions(revision)
    project = revision.project

    # go to revision page
    get(project_revision_url(project.id, revision.id))
    assert_response :success
    assert_select 'input#edit_conditions_button', count: 1

    # Click the upload file button
    post(edit_conditions_project_revision_url(project, revision, format: :js), params: { req: :show })
    assert_response :success

    # alias can't see the upload file button
    login @alias_cant_edit
    get(project_revision_url(project, revision))
    assert_response :success
    assert_select 'input#edit_conditions_button', count: 0
    login @client

    # Alias can't edit the conditions too
    login @alias_cant_edit
    conditions = {
      word_count: 100,
      max_bid: 10.0,
      auto_accept_amount: 9.0,
      bidding_duration: 2,
      project_completion_duration: 3
    }
    post(edit_conditions_project_revision_url(project, revision, format: :js), params: { req: :save, revision: conditions })
    revision.reload
    conditions.each_pair do |k, _v|
      assert_not_equal conditions[k], revision.send(k)
    end
    login @client

    # Edit the conditions
    post(edit_conditions_project_revision_url(project, revision, format: :js), params: { req: :save, revision: conditions })
    assert_response :success
    revision.reload
    conditions.each_pair do |k, _v|
      assert_equal conditions[k], revision.send(k).to_i, "Error comparing #{k}"
    end
  end

  def edit_required_fields(revision)
    project = revision.project

    # go to revision page
    get(project_revision_url(project.id, revision.id))
    assert_response :success
    assert_select 'input#edit_categories_button', count: 1

    # Click the upload file button
    post(edit_categories_project_revision_url(project, revision, format: :js), params: { req: :show })
    assert_response :success

    # alias can't see the upload file button
    login @alias_cant_edit
    get(project_revision_url(project, revision))
    assert_response :success
    assert_select 'input#edit_categories_button', count: 0
    login @client

    # Alias can't edit the language_id too
    login @alias_cant_edit
    categories = [1, 2]
    categories_param = {}
    categories.each { |l| categories_param[l] = 1 }
    post(edit_categories_project_revision_url(project, revision, format: :js), params: { req: :save, category: categories_param })
    revision.reload
    assert revision.categories.empty?
    login @client

    # Edit the language_id
    post(edit_categories_project_revision_url(project, revision, format: :js), params: { req: :save, category: categories_param })
    assert_response :success
    revision.categories.reload
    assert_equal categories, revision.categories.map(&:id)
  end

  def release_project(revision)
    project = revision.project

    # go to revision page
    get(project_revision_url(project.id, revision.id))
    assert_response :success
    assert_select 'input#release_status_button', count: 1

    # alias can't see the release button
    login @alias_cant_edit
    get(project_revision_url(project, revision))
    assert_response :success
    assert_select 'input#release_status_button', count: 0
    login @client

    # Alias can't release too
    login @alias_cant_edit
    post(edit_release_status_project_revision_url(project, revision, format: :js), params: { req: :show })
    assert_js_redirect

    revision.reload
    assert_equal 0, revision.released
    login @client

    # Release project
    post(edit_release_status_project_revision_url(project, revision, format: :js), params: { req: :show })
    assert_response :success
    assert_nil assigns(:warnings)
    revision.reload
    assert_equal 1, revision.released

    # Hide project
    post(edit_release_status_project_revision_url(project, revision, format: :js), params: { req: :hide })
    assert_response :success
    assert_nil assigns(:warnings)
    revision.reload
    assert_equal 0, revision.released

    # Release project
    post(edit_release_status_project_revision_url(project, revision, format: :js), params: { req: :show })
    assert_response :success
    assert_nil assigns(:warnings)
    revision.reload
    assert_equal 1, revision.released
  end

  def translator_apply(revision)
    project = revision.project

    # go to revision page
    get(project_revision_url(project.id, revision.id))
    assert_response :success
    assert_select 'input#bid_button', count: 1

    # Create a chat
    assert_difference 'Chat.count', 1 do
      post(project_revision_chats_url(project, revision))
      assert_response :redirect
    end

    # Go to chat
    chat = Chat.last
    get(project_revision_chat_url(project, revision, chat))
    assert_response :success
    assert_select "input[value='Bid on project']", count: 2

    # Send a message
    body = 'Testing messages'
    for_who = @client.id
    assert_difference('ActionMailer::Base.deliveries.length', 1) do
      assert_difference('chat.reload; chat.messages.size', 1) do
        post(create_message_project_revision_chat_url(project, revision, chat),
             params: { body: body, for_who1: for_who, max_idx: 1 })
        assert_response :redirect # check chats#create_message it should be redirect
      end
    end
    message = chat.messages.last
    assert_equal body, message.body

    # Bid for both languages
    revision.revision_languages.each do |rl|
      # Click in the button to load the bid form
      post(edit_bid_project_revision_chat_url(project, revision, chat, format: :js), params: { lang_id: rl.language_id })
      assert_response :success

      # Send his bid; for first language
      if rl.language_id == 2 # for first language, do not auto accept value
        assert_difference 'rl.reload; rl.bids.count', 1 do
          post(save_bid_project_revision_chat_url(project, revision, chat, format: :js),
               params: { bid: { amount: 9.5 }, commit: 'Save', do_save: 1, lang_id: rl.language_id })
          assert_response :success
        end
      else # For second one, send auto accept value
        assert_difference 'rl.reload; rl.bids.count', 1 do
          post(save_bid_project_revision_chat_url(project, revision, chat, format: :js),
               params: { bid: { amount: 9.0 }, commit: 'Save', do_save: 1, lang_id: rl.language_id })
          assert_response :success
        end
        rl.reload
        assert_equal 1, rl.bids.size
        assert_equal rl.bids.first, rl.selected_bid
      end
    end
    chat.reload
    assert_equal 2, chat.bids.count
  end

  def accept_applications(revision, payment_type)
    project = revision.project

    # go to revision page
    get(project_revision_url(project.id, revision.id))
    assert_response :success

    # alias can see the chat, not the accept bid button
    chat = revision.chats.first
    bid = chat.bids.first
    login @alias_cant_edit
    get(project_revision_chat_url(project, revision, chat))
    assert_response :success
    assert_select 'input[value="Accept bid"]', count: 0
    login @client

    # client can do everything
    get(project_revision_chat_url(project, revision, chat))
    assert_select 'input[value="Accept bid"]', count: 1
    assert_response :success

    # alias can't accept bid
    login @alias_cant_edit
    post(accept_bid_project_revision_chat_url(project, revision, chat, format: :js),
         params: { bid_id: bid.id, lang_id: bid.revision_language.language.id })
    assert_js_redirect

    bid.reload
    assert_equal nil, bid.won
    login @client

    # Client click on accept bid
    post(accept_bid_project_revision_chat_url(project, revision, chat, format: :js),
         params: { bid_id: bid.id, lang_id: bid.revision_language.language.id })
    assert_response :success

    if payment_type == :payment_project_screen
      # Client don't have enough money in his account
      revision.client.money_accounts.first.update_attribute :balance, 0

      # Click on accept bid
      post(accept_bid_project_revision_chat_url(project, revision, chat, bid_id: bid.id, format: :js))
      assert_response :success
      bid.reload
      assert_equal BID_WAITING_FOR_PAYMENT, bid.status

      # Client deposits money to his account through a standard way
      revision.client.money_accounts.first.update_attribute :balance, 9999

      # From the project screen
      post(pay_bids_with_transfer_project_revision_url(project, revision, accept: [1], format: :js))
      assert_response :success

    else # it is throught the chat screen
      # alias can't make payment
      [@alias_cant_edit, @alias_cant_pay].each do |user|
        login user
        assert_no_difference('ActionMailer::Base.deliveries.length') do
          post(transfer_bid_payment_project_revision_chat_url(project, revision, chat, format: :js),
               params: { accept: { '0' => '1', '1' => '1' }, bid_id: bid.id, lang_id: bid.revision_language.language.id })
          assert_js_redirect
        end
        bid.reload
        assert_equal nil, bid.won
      end
      session = login(@client)

      assert_difference('ActionMailer::Base.deliveries.length', 1) do
        post(transfer_bid_payment_project_revision_chat_url(project, revision, chat, format: :js),
             params: { accept: { '0' => '1' }, bid_id: bid.id, lang_id: bid.revision_language.language.id })
        assert_response :success
      end
    end

    bid.reload
    assert_equal BID_ACCEPTED, bid.status
    assert_equal 1, bid.won
    assert_equal bid.amount * 1.5, bid.account.balance
  end

  def finish_translation(revision)
    project = revision.project

    # go to revision page
    get(project_revision_url(project.id, revision.id))
    assert_response :success

    revision.revision_languages.each do |rl|
      # Access the chat page
      chat = rl.selected_bid.chat
      bid = rl.selected_bid
      get(project_revision_chat_url(project, revision, chat))
      assert_response :success
      assert_select 'input[value="Declare the work as complete"]'

      # Declare work done
      post(declare_done_project_revision_chat_url(project, revision, chat, format: :js),
           params: { bid_id: bid.id, lang_id: rl.language.id })
      assert_response :success
      bid.reload
      assert_equal BID_DECLARED_DONE, bid.status
    end
  end

  def became_reviewer(revision)
    project = revision.project
    chat = revision.chats.first
    managed_work = revision.revision_languages.first.managed_work

    # Go to work page
    get('/translator/open_work')
    assert_response :success
    assert_select "a[href='/projects/#{project.id}/revisions/#{revision.id}']"

    # go to the project page
    get(project_revision_url(project, revision))
    assert_response :success
    assert_select 'input[value="Become the reviewer for this job"]'

    # Click become reviewer button
    post(be_reviewer_managed_work_url(managed_work))
    assert_response :redirect
    managed_work.reload
    assert_equal managed_work.translator, @reviewer
  end

  def do_review(revision)
    project = revision.project
    chat = revision.chats.first
    bid = chat.bids.first
    managed_work = revision.revision_languages.first.managed_work

    # go to the chat
    get(project_revision_chat_url(project, revision, chat))
    assert_response :success
    assert_select 'input[value="Review is complete"]'

    # First click in review complete
    post(review_complete_project_revision_chat_url(project, revision, chat, format: :js),
         params: { bid_id: bid.id, lang_id: revision.languages.first.id })
    assert_response :success

    # Then confirm it
    post(finalize_review_project_revision_chat_url(project, revision, chat, format: :js),
         params: { accept: { '0' => '1', '1' => '1' }, bid_id: bid.id })
    assert_response :success
    managed_work.reload
    assert_equal MANAGED_WORK_WAITING_FOR_PAYMENT, managed_work.translation_status
  end

  def project_upload_and_setup
    # make sure we start clean
    Project.destroy_all
    Revision.delete_all
    Chat.delete_all
    Bid.delete_all
    Statistic.delete_all
    ZippedFile.destroy_all
    UserSession.delete_all

    assert_equal 0, Project.count
    assert_equal 0, Revision.count
    assert_equal 0, Chat.count
    assert_equal 0, Bid.count
    assert_equal 0, ZippedFile.count
    assert_equal 0, Statistic.count

    files_to_delete = []

    # ------------------------------ client project setup ----------------------------

    # log in as a client
    client = users(:amir)
    session = login(client)

    # create a project
    project_id = create_project(session, 'functional project')
    project = Project.find(project_id)

    # add a track to the project
    # post(url_for(:controller=>:changes, :action=>:track_project),
    # {:session=>session, :id=>project_id, :format=>'xml' } )
    # assert_response :success

    changenum = get_track_num(session)

    # create a new revision
    revision_id = create_revision(session, project_id, 'Created by test')
    revision = Revision.find(revision_id)
    changenum = assert_track_changes(session, changenum, "Changenum didn't increment after revision was created")

    display_stats('After project creation', project, revision, session)

    # ---------------- upload support files and a new version ------------------------
    support_file_id = create_support_file(session, project_id, 'sample/support_files/styles.css.gz')

    # try to upload a bad file, see that the upload fails
    f = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/PB.xml", 'rb')
    txt = f.read
    f.close
    txt = txt.gsub('$SUPPORT_FILE_ID', String(support_file_id))
    txt = txt.gsub('$REV_ID', String(revision_id + 1))
    fullpath = "#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/produced_bad.xml.gz"
    Zlib::GzipWriter.open(fullpath) do |gz|
      gz.write(txt)
    end
    files_to_delete << fullpath

    # create a project file that includes the correct support file ID
    f = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/PB.xml", 'rb')
    txt = f.read
    f.close
    txt = txt.gsub('$SUPPORT_FILE_ID', String(support_file_id))
    txt = txt.gsub('$REV_ID', String(revision_id))
    fullpath = "#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/produced.xml.gz"
    Zlib::GzipWriter.open(fullpath) do |gz|
      gz.write(txt)
    end
    files_to_delete << fullpath

    # create a project file that includes the correct support file ID
    f = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/multiple_languages.xml", 'rb')
    txt = f.read
    f.close
    txt = txt.gsub('$SUPPORT_FILE_ID', String(support_file_id))
    txt = txt.gsub('$REV_ID', String(revision_id))
    fullpath = "#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/produced_multiple_lang.xml.gz"
    Zlib::GzipWriter.open(fullpath) do |gz|
      gz.write(txt)
    end
    files_to_delete << fullpath

    fsize = File.size(fullpath)

    # upload a bad project file (upload version)
    version_id = create_version(session, project_id, revision_id, 'sample/Initial/produced_bad.xml.gz')
    display_stats('After first upload', project, revision, session)

    # get the uploaded version XML and see that all information is there
    get(url_for(controller: :versions, action: :show, project_id: project.id, revision_id: revision.id,
                id: version_id, format: 'xml'),
        session: session)
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute(String(version_id), xml.root.elements['version'], 'id')
    contents = xml.root.elements['version']
    assert_element_text('produced_bad.xml.gz', contents.elements['filename'])
    assert_element_attribute(String(client.id), contents.elements['created_by'], 'id')
    assert_element_attribute(client[:type], contents.elements['created_by'], 'type')
    assert_element_attribute(client.full_name, contents.elements['created_by'], 'name')
    assert contents.elements['modified']

    # a second upload is not possible any more
    create_version(session, project_id, revision_id, 'sample/Initial/produced_multiple_lang.xml.gz', false)
    display_stats('After third upload', project, revision, session)

    # upload this project file (upload version)
    update_version(session, project_id, revision_id, version_id, 'sample/Initial/produced.xml.gz')
    display_stats('After first update', project, revision, session)

    # update should be possible
    update_version(session, project_id, revision_id, version_id, 'sample/Initial/produced_multiple_lang.xml.gz')
    display_stats('After update', project, revision, session)

    # get the uploaded version XML and see that all information is there
    get(url_for(controller: :versions, action: :show, project_id: project.id, revision_id: revision.id,
                id: version_id, format: 'xml'),
        session: session)
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute(String(version_id), xml.root.elements['version'], 'id')
    contents = xml.root.elements['version']
    assert_element_text('produced_multiple_lang.xml.gz', contents.elements['filename'])
    assert_element_text(String(fsize), contents.elements['size'])
    assert_element_attribute(String(client.id), contents.elements['created_by'], 'id')
    assert_element_attribute(client[:type], contents.elements['created_by'], 'type')
    assert_element_attribute(client.full_name, contents.elements['created_by'], 'name')
    assert contents.elements['modified']

    # update the project's description
    description = 'Some very interesting story'
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_description, project_id: project_id,
                                    id: revision_id),
                     session: session, req: 'save', revision: { description: description })
    assert_response :success
    revision.reload
    assert_equal description, revision.description

    # update the project's source language
    source_language = 1

    get(url_for(controller: :revisions, action: :show, project_id: project.id, id: revision.id, format: 'xml'),
        session: session)
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute(String(revision_id), xml.root.elements['revision'], 'id')
    assert_element_attribute('0', xml.root.elements['revision'], 'released')
    assert_element_attribute('0', xml.root.elements['revision'], 'open_to_bids')
    contents = xml.root.elements['revision']
    assert_element_attribute(String(version_id), contents.elements['version'], 'id')
    stats = contents.elements['stats']
    assert stats
    # puts stats
    assert_element_attribute_positive(stats.elements['document_count'], 'count')
    assert_element_attribute_positive(stats.elements['sentence_count'], 'count')
    assert_element_attribute_positive(stats.elements['word_count'], 'count')
    # assert_element_attribute(263.to_s,stats.elements['word_count'],'count')
    assert_element_attribute_positive(stats.elements['support_files_count'], 'count')

    english = languages(:English)
    stats = revision.get_stats
    assert stats
    ws = stats[STATISTICS_WORDS]
    assert ws
    ews = ws[english.id]
    assert ews
    assert_equal 264, ews[WORDS_STATUS_DONE_CODE]

    # revision.reload

    get(url_for(controller: :projects, action: :show, id: project_id, format: 'xml'),
        session: session)
    assert_response :success
    xml = get_xml_tree(@response.body)
    # puts @response.body

    # update the revision's conditions
    max_bid = 1.2
    bidding_duration = 3
    project_completion_duration = 5
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_conditions,
                                    project_id: project_id, id: revision_id),
                     session: session, req: 'save', revision: { max_bid: max_bid,
                                                                bidding_duration: bidding_duration,
                                                                project_completion_duration: project_completion_duration,
                                                                word_count: 1 })
    assert_response :success
    revision.reload
    assert_equal max_bid, revision.max_bid
    assert_equal bidding_duration, revision.bidding_duration
    assert_equal project_completion_duration, revision.project_completion_duration

    # set the revision's categories
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_categories),
                     session: session, project_id: project_id, id: revision_id, req: 'save',
                     categories: { '1' => '1', '2' => '1' })
    assert_response :success

    # languages
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_languages),
                     session: session, project_id: project_id, id: revision_id, req: 'save',
                     language: { '2' => '1', '3' => '1', '4' => '1' })
    assert_response :success

    # release this revision
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_release_status),
                     session: session, project_id: project_id, id: revision_id, req: 'show')
    assert_response :success
    assert_nil assigns(:warnings)
    changenum = assert_track_changes(session, changenum, "Changenum didn't increment after revision was released")

    get(url_for(controller: :revisions, action: :show, project_id: project.id, id: revision.id, format: 'xml'),
        session: session)
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute(String(revision_id), xml.root.elements['revision'], 'id')
    assert_element_attribute('1', xml.root.elements['revision'], 'released')

    # delete all temporary files
    files_to_delete.each { |file_to_delete| File.delete(file_to_delete) }

    check_client_pages(client, session)

  end

  def revision_locking
    client = users(:amir)
    Project.destroy_all
    project = setup_full_project(client, 'multiple revisions')

    session = login(client)

    revision = project.revisions[-1]

    # release this revision
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_release_status),
                     session: session, project_id: project.id, id: revision.id, req: 'show')
    assert_response :success
    assert_nil assigns(:warnings)
    revision.reload
    assert_equal 1, revision.released

    # check the work_complete status for this revision
    get(url_for(controller: :revisions, action: :show, project_id: project.id, id: revision.id, format: 'xml'),
        session: session)
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_text('0', xml.root.elements['revision'].elements['work_complete'])

    create_revision(session, project.id, 'dummy', false)

    translator = users(:orit)
    xsession = login(translator)

    bids = []
    # create a chat in this revision
    chat_id = create_chat(xsession, project.id, revision.id)
    chat = Chat.find(chat_id)

    amount = 0.09
    for language in revision.languages
      bids << translator_bid(xsession, chat, language, amount)
    end

    # still cannot create a new revision
    create_revision(session, project.id, 'dummy', false)

    # accept all bids
    client_accepts_bids(session, bids, BID_ACCEPTED)

    # still cannot create a new revision
    create_revision(session, project.id, 'dummy', false)

    # check the work_complete status for this revision
    get(url_for(controller: :revisions, action: :show, project_id: project.id, id: revision.id, format: 'xml'),
        session: session)
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_text('0', xml.root.elements['revision'].elements['work_complete'])

    translator_completes_work(xsession, chat)

    client_finalizes_bids(session, bids)

    # check the work_complete status for this revision
    get(url_for(controller: :revisions, action: :show, project_id: project.id, id: revision.id, format: 'xml'),
        session: session)
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_text('1', xml.root.elements['revision'].elements['work_complete'])

    # now, a new revision can be created
    create_revision(session, project.id, 'dummy', true)

    # nothing can be changed anymore in the old revision
    # release this revision
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_release_status),
                     session: session, project_id: project.id, id: revision.id, req: 'hide')
    assert_response :success
    revision.reload
    assert_equal 1, revision.released

    # new chats cannot be created too
    create_chat(xsession, project.id, revision.id, false)

    check_client_pages(client, session)
  end

  def display_stats(message, project, revision, session)
    # puts "\n\n#{message}"
    # get(url_for(controller: :revisions, action: :show, project_id: project.id, id: revision.id, format: 'xml'),
    #     session: session)
    # assert_response :success
    # xml = get_xml_tree(@response.body)
    # contents = xml.root.elements['revision']
    # stats = contents.elements['stats']
    # assert stats
    # puts stats
  end

end
