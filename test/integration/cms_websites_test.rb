require "#{File.dirname(__FILE__)}/../test_helper"

class CmsWebsitesTest < ActionDispatch::IntegrationTest
  fixtures :all

  def test_add_stats
    offer = website_translation_offers(:amir_drupal_rpc_en_es)
    website = offer.website

    CmsCount.delete_all

    counts = [[offer.id, STATISTICS_DOCUMENTS, COUNT_ORIG_LANGUAGE, 100, nil, 3, 'TLV', nil],
              [offer.id, STATISTICS_DOCUMENTS, COUNT_TRANSLATED, 80, 'Drupal', 0, nil, 'Jake']]

    args = {}
    idx = 1
    counts.each do |count|
      args["offer_id#{idx}"] = count[0]
      args["kind#{idx}"] = count[1]
      args["status#{idx}"] = count[2]
      args["count#{idx}"] = count[3]
      args["service#{idx}"] = count[4] if count[4]
      args["priority#{idx}"] = count[5] if count[5]
      args["code#{idx}"] = count[6] if count[6]
      args["translator_name#{idx}"] = count[7] if count[7]
      idx += 1
    end

    post url_for(controller: '/websites', action: :add_counts, id: website.id, format: :xml),
         params: { accesskey: website.accesskey, num_elements: counts.length }.merge(args)
    assert_response :success

    xml = get_xml_tree(@response.body)

    assert_element_text(counts.length.to_s, xml.root.elements['added'])

    offer.reload
    assert_equal 1, website.cms_count_groups.length

    group = website.cms_count_groups[0]
    assert_equal counts.length, group.cms_counts.length

    idx = 0
    counts.each do |count|
      cms_count = group.cms_counts[idx]
      assert cms_count
      assert_equal website, cms_count.website_translation_offer.website

      assert_equal count[1], cms_count.kind
      assert_equal count[2], cms_count.status
      assert_equal count[3], cms_count.count
      assert_equal count[4], cms_count.service unless count[4].blank?
      assert_equal count[5], cms_count.priority unless count[5].blank?
      assert_equal count[6], cms_count.code unless count[6].blank?
      assert_equal count[7], cms_count.translator_name unless count[7].blank?
      idx += 1
    end
  end

  def test_store_file
    client = users(:amir)
    session = login(client)

    CmsRequest.destroy_all
    ManagedWork.delete_all

    website = websites(:amir_wp)

    files_to_delete = []

    get(url_for(controller: '/wpml/websites', action: :show, id: website.id))
    assert_response :success

    # create a project file that includes the correct support file ID
    f = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/PB.xml", 'rb')
    txt = f.read
    f.close
    fullpath = "#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/produced2.xml.gz"
    Zlib::GzipWriter.open(fullpath) do |gz|
      gz.write(txt)
    end
    files_to_delete << fullpath

    fname = 'sample/Initial/produced2.xml.gz'

    fdata = fixture_file_upload(fname, 'application/octet-stream')
    multipart_post url_for(controller: '/websites', action: :store, id: website.id, format: 'xml'),
                   cms_container: { 'uploaded_data' => fdata }
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute('Container created', xml.root.elements['result'], 'message')
    cms_container_id = get_element_attribute(xml.root.elements['result'], 'id').to_i
    assert cms_container_id
    assert_equal website.cms_container.id, cms_container_id

    website.reload
    assert website.cms_container
    assert_equal 'produced2.xml.gz', website.cms_container.filename
    assert_equal File.stat(fullpath).size, website.cms_container.size

    get(url_for(controller: '/websites', action: :get, id: website.id, format: :xml))
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert xml.root.elements['cms_container']
    assert_element_text(website.cms_container.filename, xml.root.elements['cms_container/filename'])
    assert_element_text(File.stat(fullpath).size.to_s, xml.root.elements['cms_container/size'])

    # ----- update the file - replace with a different one -----
    f = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/proj5.xml", 'rb')
    txt = f.read
    f.close
    fullpath = "#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/produced1.xml.gz"
    Zlib::GzipWriter.open(fullpath) do |gz|
      gz.write(txt)
    end
    files_to_delete << fullpath

    fname = 'sample/Initial/produced1.xml.gz'

    fdata = fixture_file_upload(fname, 'application/octet-stream')
    multipart_post url_for(controller: '/websites', action: :store, id: website.id, format: 'xml'),
                   cms_container: { 'uploaded_data' => fdata }
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute('Container updated', xml.root.elements['result'], 'message')
    cms_container_id = get_element_attribute(xml.root.elements['result'], 'id').to_i
    assert cms_container_id
    assert_equal website.cms_container.id, cms_container_id

    website.reload
    assert website.cms_container
    assert_equal 'produced1.xml.gz', website.cms_container.filename
    assert_equal File.stat(fullpath).size, website.cms_container.size

    get(url_for(controller: '/websites', action: :get, id: website.id, format: :xml))
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert xml.root.elements['cms_container']
    assert_element_text(website.cms_container.filename, xml.root.elements['cms_container/filename'])
    assert_element_text(File.stat(fullpath).size.to_s, xml.root.elements['cms_container/size'])

    # download the contents of the file
    get(url_for(controller: '/websites', action: :get, id: website.id))
    assert_response :success

    # delete all temporary files
    files_to_delete.each { |file_to_delete| File.delete(file_to_delete) }
  end

  def test_add_in_container
    client = users(:amir)
    session = login(client)

    CmsRequest.destroy_all
    ManagedWork.delete_all

    website = websites(:amir_wp)

    orig_language = languages(:English)
    translation_languages = [languages(:Spanish)]

    fdata_args = {}
    fdata_args['doc_count'] = 0

    idx = 1
    translation_languages.each do |tl|
      fdata_args["to_language#{idx}"] = tl.name
      idx += 1
    end

    title = 'Orig title'
    permlink = 'link1-en'
    container = 'ABC123'
    post url_for(controller: '/cms_requests', action: :create, website_id: website.id, format: 'xml'),
         params: {
           accesskey: website.accesskey,
           orig_language: orig_language.name,
           title: title, permlink: permlink, container: container
         }.merge(fdata_args)
    assert_response :success
    xml = get_xml_tree(@response.body)

    assert_element_attribute('Upload created', xml.root.elements['result'], 'message')
    cms_request_id = get_element_attribute(xml.root.elements['result'], 'id').to_i

    cms_request1 = CmsRequest.find(cms_request_id)
    assert cms_request1
    assert_equal container, cms_request1.container

    # send another one
    post url_for(controller: '/cms_requests', action: :create, website_id: website.id, format: 'xml'),
         params:                 {
           accesskey: website.accesskey,
           orig_language: orig_language.name,
           title: title, permlink: permlink, container: container
         }.merge(fdata_args)
    assert_response :success
    xml = get_xml_tree(@response.body)

    assert_element_attribute('Upload created', xml.root.elements['result'], 'message')
    cms_request_id = get_element_attribute(xml.root.elements['result'], 'id').to_i

    cms_request2 = CmsRequest.find(cms_request_id)
    assert cms_request2
    assert_equal container, cms_request2.container

    assert_not_equal cms_request2, cms_request1

    # third, different container
    post url_for(controller: '/cms_requests', action: :create, website_id: website.id, format: 'xml'),
         params: {
           accesskey: website.accesskey,
           orig_language: orig_language.name,
           title: title, permlink: permlink, container: 'hello'
         }.merge(fdata_args)
    assert_response :success
    xml = get_xml_tree(@response.body)

    assert_element_attribute('Upload created', xml.root.elements['result'], 'message')
    cms_request_id = get_element_attribute(xml.root.elements['result'], 'id').to_i

    cms_request3 = CmsRequest.find(cms_request_id)
    assert cms_request3
    assert_equal 'hello', cms_request3.container

    get(url_for(controller: '/cms_requests', action: :index, website_id: website.id, container: container, format: 'xml'))
    assert_response :success
    # xml = get_xml_tree(@response.body)
    # puts xml

    cms_requests = assigns(:cms_requests)
    assert_equal 2, cms_requests.length
    cms_requests.each do |cms_request|
      assert_equal container, cms_request.container
    end
  end

  # --- at the end of this test, we also transfer the account to another user --

  def test_send_and_assign_with_enough_balance
    CmsRequest.destroy_all
    ManagedWork.delete_all
    PendingMoneyTransaction.delete_all!

    files_to_delete = []

    client = users(:amir)
    WebMessage.delete_all

    translator = users(:orit)
    website = websites(:amir_wp)

    init_email_deliveries
    chat = run_send_request(client, translator, website, 1000)
    revision = chat.revision
    project = revision.project

    cms_request = revision.cms_request
    assert cms_request

    spanish = languages(:Spanish)

    # --- translator returns the completed translation

    # since the translator selected himself, there's no reason to send an email notification
    total_amount = 0

    check_emails_delivered(0)

    chat.bids.each do |bid|
      assert_equal BID_ACCEPTED, bid.status
      assert_equal 1, bid.won
      contract = website.website_translation_contracts.joins(:website_translation_offer).where('(website_translation_offers.from_language_id=?) AND (website_translation_offers.to_language_id=?) AND (website_translation_contracts.status=?)', revision.language_id, bid.revision_language.language_id, TRANSLATION_CONTRACT_ACCEPTED).first
      assert contract
      assert_equal contract.amount, bid.amount
      assert_equal contract.currency, bid.currency

      # check that the bid has an account with the right sum
      assert bid.account
      expected_amount = contract.amount * revision.lang_word_count(bid.revision_language.language)
      assert expected_amount > 0
      assert_same_amount(expected_amount, bid.account.balance)

      total_amount += expected_amount
    end

    client_account = client.find_or_create_account(DEFAULT_CURRENCY_ID)
    assert_equal 0, (client_account.pending_total_expenses[0] - client_account.hold_sum)

    # check that the project was assigned OK to the translator
    check_after_translator_assignment(client, translator, website, revision)

    # create a new version, all texts are completed
    # ---------------- upload support files and a new version ------------------------
    # create a project file that includes the correct support file ID
    stream = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/with_ignores/proj2_complete.xml", 'rb')
    support_file_ids = { 355 => 1 }
    listener = XmlRevisionChanger.new('Hotdog', 'veryfirst', revision.id, support_file_ids)
    parser = REXML::Parsers::StreamParser.new(stream, listener)
    parser.parse
    stream.close

    fullpath = "#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/produced_complete.xml.gz"
    Zlib::GzipWriter.open(fullpath) do |gz|
      gz.write(listener.result)
    end
    files_to_delete << fullpath

    session = login(translator)

    check_emails_delivered(0)
    trans_version_id = create_version(session, project.id, revision.id, 'sample/Initial/produced_complete.xml.gz', true, 1)
    check_emails_delivered(0)

    logout(session)

    # --- also do the output store test here ---
    cms_request = website.cms_requests[-1]
    assert cms_request.cms_target_languages.length == 1

    fname = 'sample/support_files/styles.css.gz'
    fdata = fixture_file_upload(fname, 'application/octet-stream')

    cms_target_language = cms_request.cms_target_language
    multipart_post(url_for(controller: '/cms_requests', action: :store_output, website_id: website.id, id: cms_request.id,
                           format: :xml),
                   accesskey: website.accesskey, language_id: cms_target_language.language_id, cms_download: { uploaded_data: fdata, description: 'HTML output' })
    assert_response :success

    xml = get_xml_tree(@response.body)
    cms_download_id = get_element_attribute(xml.root.elements['result'], 'id').to_i
    cms_download = CmsDownload.find(cms_download_id)
    assert cms_download
    assert_equal cms_target_language, cms_download.cms_target_language

    # upload again, see that the file is only updated
    multipart_post(url_for(controller: '/cms_requests', action: :store_output, website_id: website.id, id: cms_request.id,
                           format: :xml),
                   accesskey: website.accesskey, language_id: cms_target_language.language_id, cms_download: { uploaded_data: fdata, description: 'HTML output' })
    assert_response :success

    cms_target_language.reload
    assert_equal 1, cms_target_language.cms_downloads.length

    xml = get_xml_tree(@response.body)
    cms_download_id = get_element_attribute(xml.root.elements['result'], 'id').to_i
    assert_not_equal cms_download_id, cms_download.id

    # before setting the title, it should be blank
    assert_nil cms_target_language.title

    # upload a second file, with a different description. Also, set the title
    title = "title for translation in #{cms_target_language.language.name}"
    multipart_post(url_for(controller: '/cms_requests', action: :store_output, website_id: website.id, id: cms_request.id,
                           format: :xml),
                   accesskey: website.accesskey, language_id: cms_target_language.language_id, title: title, cms_download: { uploaded_data: fdata, description: 'Meta data' })
    assert_response :success

    cms_target_language.reload
    assert_equal 2, cms_target_language.cms_downloads.length
    assert_equal title, cms_target_language.title

    # try to download the uploaded files
    ['HTML output', 'Meta data', nil, 'xxxx'].each do |description|
      get(url_for(controller: '/cms_requests', action: :cms_download, website_id: website.id, id: cms_request.id,
                  accesskey: website.accesskey, language: cms_target_language.language.name, description: description, format: :xml))
      assert_response :success

      xml = get_xml_tree(@response.body)
      # puts xml
      if description == 'xxxx'
        assert_element_text('cannot locate this download', xml.root.elements['status'])
      else
        cms_download_id = get_element_attribute(xml.root.elements['cms_download'], 'id').to_i
        cms_download = CmsDownload.find(cms_download_id)
        assert cms_download
        assert_equal cms_target_language, cms_download.cms_target_language
        assert_equal description, cms_download.description if description
      end
    end
    get(url_for(controller: '/cms_requests', action: :cms_download, website_id: website.id, id: cms_request.id,
                accesskey: website.accesskey, language: 'problem language', format: :xml))
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_text('cannot find this language', xml.root.elements['status'])

    get(url_for(controller: '/cms_requests', action: :cms_download, website_id: website.id, id: cms_request.id,
                accesskey: website.accesskey, language: 'French', format: :xml))
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_text('cannot locate this output language', xml.root.elements['status'])

    get(url_for(controller: '/cms_requests', action: :show, website_id: website.id, id: cms_request.id, format: :xml, accesskey: website.accesskey))
    assert_response :success

    cms_request.reload

    # update the permlink to the translations
    cms_target_language = cms_request.cms_target_language
    permlink = "link-to-translated-post-#{cms_target_language.language.name}"
    post url_for(controller: '/cms_requests', action: :update_permlink, website_id: website.id, id: cms_request.id, format: :xml),
         params: { accesskey: website.accesskey, language: cms_target_language.language.name, permlink: permlink }
    assert_response :success
    cms_target_language.reload
    assert_equal permlink, cms_target_language.permlink
    xml = get_xml_tree(@response.body)
    assert_element_attribute('Permlink updated', xml.root.elements['result'], 'message')
    assert_element_attribute(permlink, xml.root.elements['result'], 'permlink')

    # --- update the original language permlink
    permlink = 'link-to-original-post'
    post url_for(controller: '/cms_requests', action: :update_permlink, website_id: website.id, id: cms_request.id, format: :xml),
         params: { accesskey: website.accesskey, permlink: permlink }
    assert_response :success
    cms_request.reload
    assert_equal permlink, cms_request.permlink
    xml = get_xml_tree(@response.body)
    assert_element_attribute('Permlink updated', xml.root.elements['result'], 'message')
    assert_element_attribute(permlink, xml.root.elements['result'], 'permlink')

    get(url_for(controller: '/websites', action: :links, id: website.id, format: :xml, accesskey: website.accesskey))
    assert_response :success

    link_map = assigns(:link_map)
    assert link_map
    assert !link_map.keys.empty?
    assert_equal cms_request, link_map.keys[0]

    # check with delivery notificatins enabled
    website.update_attributes!(notifications: WEBSITE_NOTIFY_DELIVERY)

    # indicate that TAS finished handling
    post url_for(controller: '/cms_requests', action: :notify_tas_done, website_id: website.id, id: cms_request.id, format: 'xml'),
         params: { accesskey: website.accesskey }
    assert_response :success

    cms_request.reload
    assert_not_nil cms_request.completed_at

    website.update_attributes!(notifications: 0)

    # --- finalize the work and get paid
    session = login(translator)

    get(url_for(controller: '/chats', action: :show, project_id: chat.revision.project_id, revision_id: chat.revision_id, id: chat.id))
    assert_response :success

    account = translator.find_or_create_account(DEFAULT_CURRENCY_ID)
    translator_balance = account.balance
    root_account = RootAccount.first
    unless root_account
      root_account = RootAccount.create(balance: 0, currency_id: DEFAULT_CURRENCY_ID)
    end
    root_balance = root_account.balance

    chat.bids.each do |bid|
      bid_amount = bid.account.balance
      assert_not_equal 0, bid_amount

      cms_target_language = bid.chat.revision.cms_request.cms_target_languages.where('language_id=?', bid.revision_language.language.id).first
      assert cms_target_language

      xml_http_request(:post, url_for(controller: '/chats', action: :declare_done, project_id: chat.revision.project_id, revision_id: chat.revision_id, id: chat.id),
                       lang_id: bid.revision_language.language_id, bid_id: bid.id)
      assert_response :success

      cms_target_language.reload

      check_emails_delivered(0)

      if bid.revision_language.language == spanish
        expected_status = CMS_TARGET_LANGUAGE_TRANSLATED
      elsif bid.revision_language.language == german
        expected_status = CMS_TARGET_LANGUAGE_ASSIGNED
      else
        assert false
      end
      assert_equal expected_status, cms_target_language.status

      bid.reload
      if bid.revision_language.language == spanish
        assert_equal BID_COMPLETED, bid.status
        assert_equal 0, bid.account.balance

        account.reload
        root_account.reload

        assert_same_amount(translator_balance + (bid_amount * (1 - FEE_RATE)), account.balance)
        assert_same_amount(root_balance + (bid_amount * FEE_RATE), root_account.balance)

        translator_balance = account.balance
        root_balance = root_account.balance

        expected_status = CMS_TARGET_LANGUAGE_TRANSLATED
      else
        assert_equal BID_ACCEPTED, bid.status
        expected_status = CMS_TARGET_LANGUAGE_ASSIGNED
      end
      assert_equal expected_status, cms_target_language.status

      if expected_status == CMS_TARGET_LANGUAGE_TRANSLATED
        # make sure that the bid starts completed
        assert_equal BID_COMPLETED, bid.status
      end
    end

    logout(session)
  end

  def test_send_to_specific_translator
    CmsRequest.destroy_all
    ManagedWork.delete_all
    PendingMoneyTransaction.delete_all

    files_to_delete = []

    client = users(:amir)
    WebMessage.delete_all

    init_email_deliveries

    translator1 = users(:orit)
    translator2 = users(:newbi)
    translator3 = users(:guy)

    website = websites(:amir_two_translators)

    client_balance = 1000

    client_account = client.find_or_create_account(DEFAULT_CURRENCY_ID)
    client_account.update_attributes!(balance: client_balance)

    get(url_for(controller: '/cms_requests', action: :index, website_id: website.id, format: 'xml', accesskey: website.accesskey))
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_equal 0, assigns(:cms_requests).length

    fnames = ['sample/support_files/styles.css.gz', 'sample/support_files/images/bluebottom.gif.gz']

    orig_language = languages(:English)
    translation_languages = [languages(:Spanish)]

    cms_request, project, revision, ts = create_cms_request(client, fnames, orig_language, translation_languages, website, nil, nil, false, nil, translator2)
    assert_equal ts, UserSession.where(long_life: 1).order('id DESC').first

    assert_equal translator2, cms_request.cms_target_language.translator

    # now, log in as translator and see that we can get this project
    session = login(translator1)

    # Create a PendingMoneyTransaction for the CmsRequest.
    amount, = cms_request.calculate_required_balance
    PendingMoneyTransaction.reserve_money_for_cms_requests([cms_request]) if client_balance > amount

    get(url_for(controller: '/translator', action: :open_work))
    assert_response :success

    open_website_translation_work = assigns(:open_website_translation_work)
    assert_equal 0, open_website_translation_work.length

    # now, log in as translator and see that we can get this project
    session = login(translator2)

    prev_chats_length = revision.chats.length

    get(url_for(controller: :translator))
    assert_response :success
    prev_chats = assigns(:chats).length

    get(url_for(controller: '/translator', action: :open_work))
    assert_response :success

    open_website_translation_work = assigns(:open_website_translation_work)

    assert_equal 1, open_website_translation_work.length, "Expected one open_website_translation_work, got #{open_website_translation_work.length}"
    assert_equal cms_request, open_website_translation_work[0][0]

    # check translator notifications
    # debug_print('before periodic checker')
    checker = PeriodicChecker.new(Time.now)
    cnt = checker.per_profile_mailer
    # debug_print('after periodic checker')
    assert cnt > 0
    check_emails_delivered(cnt)

    # next time, translators are no longer notified about these requests
    cnt = checker.per_profile_mailer
    assert_equal 0, cnt

    # look at the details of the cms_request
    get(url_for(controller: '/cms_requests', action: :show, website_id: website.id, id: cms_request.id))
    assert_response :success

    open_cms_target_languages = assigns(:open_cms_target_languages)
    assert open_cms_target_languages
    assert_equal 1, open_cms_target_languages.length

    target_languages = {}
    cms_target_languages = []
    open_cms_target_languages.each do |ol|
      target_languages["cms_target_language[#{ol.id}]"] = 1

      cms_target_language = CmsTargetLanguage.find(ol.id)
      assert cms_target_language
      cms_target_languages << cms_target_language
    end

    # ask to assign the requested languages
    post url_for(controller: '/cms_requests', action: :assign_to_me, website_id: website.id, id: cms_request.id),
         params: target_languages
    assert_response :success

    # check that the revision languages were created
    revision.reload
    assert_equal open_cms_target_languages.length, revision.revision_languages.length

    assert_equal prev_chats_length + 1, revision.chats.length
    chat = revision.chats[-1]
    assert_equal translator2, chat.translator
    assert_equal open_cms_target_languages.length, chat.bids.length

    # see that this chat now appears for the translator
    get(url_for(controller: :translator))
    assert_response :success

    assert_equal prev_chats + 1, assigns(:chats).length

    # -- test with an invalid translator ID
    cms_request, project, revision, ts = create_cms_request(client, fnames, orig_language, translation_languages, website, nil, nil, false, nil, translator3)
    assert_equal ts, UserSession.where(long_life: 1).order('id DESC').first

    assert_equal nil, cms_request.cms_target_language.translator
  end

  skip def test_translate_with_tm # fails
    CmsRequest.destroy_all
    ManagedWork.delete_all
    Tu.delete_all

    files_to_delete = []

    client = users(:amir)
    WebMessage.delete_all

    translator = users(:orit)
    website = websites(:amir_wp)

    init_email_deliveries

    # --------------------

    client_balance = 1000

    client_account = client.find_or_create_account(DEFAULT_CURRENCY_ID)
    client_account.update_attributes!(balance: client_balance)

    get(url_for(controller: '/cms_requests', action: :index, website_id: website.id, format: 'xml', accesskey: website.accesskey))
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_equal 0, assigns(:cms_requests).length

    fnames = ['sample/support_files/styles.css.gz', 'sample/support_files/images/bluebottom.gif.gz']

    orig_language = languages(:English)
    translation_languages = [languages(:Spanish)]

    # puts "\n\n\n=== uploading project first time ===\n\n\n"
    cms_request, project, revision, ts = create_cms_request(client, fnames, orig_language, translation_languages, website, nil, nil)

    # --------------------

    # now, log in as translator and see that we can get this project
    session = login(translator)

    prev_chats_length = revision.chats.length

    get(url_for(controller: :translator))
    assert_response :success
    prev_chats = assigns(:chats).length

    get(url_for(controller: '/translator', action: :open_work))
    assert_response :success

    open_website_translation_work = assigns(:open_website_translation_work)

    assert_equal 1, open_website_translation_work.length, "Expected one open_website_translation_work, got #{open_website_translation_work.length}"
    assert_equal cms_request, open_website_translation_work[0][0]

    # look at the details of the cms_request
    get(url_for(controller: '/cms_requests', action: :show, website_id: website.id, id: cms_request.id))
    assert_response :success

    open_cms_target_languages = assigns(:open_cms_target_languages)
    assert open_cms_target_languages
    assert_equal 1, open_cms_target_languages.length

    target_languages = {}
    cms_target_languages = []
    open_cms_target_languages.each do |ol|
      target_languages["cms_target_language[#{ol.id}]"] = 1

      cms_target_language = CmsTargetLanguage.find(ol.id)
      assert cms_target_language
      cms_target_languages << cms_target_language
    end

    # ask to assign the requested languages
    post url_for(controller: '/cms_requests', action: :assign_to_me, website_id: website.id, id: cms_request.id),
         params: target_languages
    assert_response :success

    # check that the revision langauges were created
    revision.reload
    assert open_cms_target_languages.length <= revision.revision_languages.length

    assert_equal prev_chats_length + 1, revision.chats.length
    chat = revision.chats[-1]
    assert_equal translator, chat.translator
    assert_equal open_cms_target_languages.length, chat.bids.length

    # see that this chat now appears for the translator
    get(url_for(controller: :translator))
    assert_response :success

    assert_equal prev_chats + 1, assigns(:chats).length

    get(url_for(controller: '/translator', action: :open_work))
    assert_response :success

    # -------------------
    total_amount = 0
    chat.bids.each do |bid|
      assert_equal BID_ACCEPTED, bid.status
      assert_equal 1, bid.won
      contract = website.website_translation_contracts.joins(:website_translation_offer).where('(website_translation_offers.from_language_id=?) AND (website_translation_offers.to_language_id=?) AND (website_translation_contracts.status=?)', revision.language_id, bid.revision_language.language_id, TRANSLATION_CONTRACT_ACCEPTED).first
      assert contract
      assert_equal contract.amount, bid.amount
      assert_equal contract.currency, bid.currency

      # check that the bid has an account with the right sum
      assert bid.account
      expected_amount = contract.amount * revision.lang_word_count(bid.revision_language.language)
      assert_equal 559, revision.lang_word_count(bid.revision_language.language)
      assert expected_amount > 0
      assert_same_amount(expected_amount, bid.account.balance)

      total_amount += expected_amount
    end

    client_account = client.find_or_create_account(DEFAULT_CURRENCY_ID)

    # check that the project was assigned OK to the translator
    check_after_translator_assignment(client, translator, website, revision)

    # create a new version, all texts are completed
    # ---------------- upload support files and a new version ------------------------
    # create a project file that includes the correct support file ID
    stream = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/PB_complete.xml", 'rb')
    support_file_ids = { 355 => 1 }
    listener = XmlRevisionChanger.new('Hotdog', 'veryfirst', revision.id, support_file_ids)
    parser = REXML::Parsers::StreamParser.new(stream, listener)
    parser.parse
    stream.close

    fullpath = "#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/produced_PB_complete.xml.gz"
    Zlib::GzipWriter.open(fullpath) do |gz|
      gz.write(listener.result)
    end
    files_to_delete << fullpath

    session = login(translator)

    assert_equal 0, translator.tus.length
    assert_equal 0, client.tus.length

    # puts "\n\n\n=== translator completes the project ===\n\n\n"
    check_emails_delivered(0)
    trans_version_id = create_version(session, project.id, revision.id, 'sample/Initial/produced_PB_complete.xml.gz', true, 1)
    check_emails_delivered(0)

    translator.reload
    client.reload

    assert_equal 66, translator.tus.length
    assert_equal 66, translator.tus.where('tus.status = ?', TU_COMPLETE).length
    assert_equal 66, client.tus.length

    # translator.tus.where('tus.status = ?',TU_COMPLETE).each do |tu|
    # puts "TU.#{tu.id} #{tu.from_language.name}->#{tu.to_language.name} - tu.original=#{tu.original}, -tu.translation=#{tu.translation}, tu.signature=#{tu.signature}"
    # end

    # client.tus.each do |tu|
    # puts "\n -------\ntu.#{tu.id}: signature=#{tu.signature}, original=#{tu.original}, translation=#{tu.translation}, status=#{tu.status}\n"
    # end

    logout(session)

    # --------- 1st job complete. Now we send it again and see that the TM translates all ------------

    # puts "\n\n\n=== uploading project second time ===\n\n\n"
    cms_request2, project2, revision2, ts2 = create_cms_request(client, fnames, orig_language, translation_languages, website, nil, nil)

    # now, log in as translator and see that we can get this project
    session = login(translator)

    prev_chats_length = revision2.chats.length

    get(url_for(controller: :translator))
    assert_response :success
    prev_chats = assigns(:chats).length

    get(url_for(controller: '/translator', action: :open_work))
    assert_response :success
    open_website_translation_work = assigns(:open_website_translation_work)

    assert_equal 1, open_website_translation_work.length, "Expected one open_website_translation_work, got #{open_website_translation_work.length}"
    assert_equal cms_request2, open_website_translation_work[0][0]

    # look at the details of the cms_request
    get(url_for(controller: '/cms_requests', action: :show, website_id: website.id, id: cms_request2.id))
    assert_response :success

    open_cms_target_languages = assigns(:open_cms_target_languages)
    assert open_cms_target_languages
    assert_equal 1, open_cms_target_languages.length

    target_languages = {}
    cms_target_languages = []
    open_cms_target_languages.each do |ol|
      target_languages["cms_target_language[#{ol.id}]"] = 1

      cms_target_language = CmsTargetLanguage.find(ol.id)
      assert cms_target_language
      cms_target_languages << cms_target_language
    end

    # puts "\n\n\n=== translator assigns project (TM should run now) ===\n\n\n"
    # ask to assign the requested languages
    post url_for(controller: '/cms_requests', action: :assign_to_me, website_id: website.id, id: cms_request2.id),
         params: target_languages
    assert_response :success

    # check that the revision langauges were created
    revision2.reload
    assert open_cms_target_languages.length <= revision2.revision_languages.length

    assert_equal prev_chats_length + 1, revision2.chats.length
    chat2 = revision2.chats[-1]
    assert_equal translator, chat2.translator
    assert_equal open_cms_target_languages.length, chat2.bids.length

    # see that this chat now appears for the translator
    get(url_for(controller: :translator))
    assert_response :success

    assert_equal prev_chats + 1, assigns(:chats).length

    get(url_for(controller: '/translator', action: :open_work))
    assert_response :success

    # -------------------
    total_amount = 0
    chat2.bids.each do |bid|
      assert_equal BID_ACCEPTED, bid.status
      assert_equal 1, bid.won
      contract = website.website_translation_contracts.joins(:website_translation_offer).where('(website_translation_offers.from_language_id=?) AND (website_translation_offers.to_language_id=?) AND (website_translation_contracts.status=?)', revision.language_id, bid.revision_language.language_id, TRANSLATION_CONTRACT_ACCEPTED).first
      assert contract
      assert_equal contract.amount, bid.amount
      assert_equal contract.currency, bid.currency

      # check that the bid has an account with the right sum
      assert bid.account
      expected_amount = contract.amount * revision2.lang_word_count(bid.revision_language.language)
      # puts "\n\n=== Checking #{bid.revision_language.language.name} ==="
      assert_equal 125, revision2.lang_word_count(bid.revision_language.language)
      assert expected_amount > 0
      assert_same_amount(expected_amount, bid.account.balance, 'Expected: %.2f, bid account: %.2f' % [expected_amount, bid.account.balance])

      total_amount += expected_amount
    end

    # delete all temporary files
    files_to_delete.each { |file_to_delete| File.delete(file_to_delete) }

    logout(session)

  end

  # this is the case when the user sends a document without any texts
  def test_translate_blank_document
    CmsRequest.destroy_all
    ManagedWork.delete_all
    PendingMoneyTransaction.delete_all

    files_to_delete = []

    client = users(:amir)
    WebMessage.delete_all

    translator = users(:orit)
    website = websites(:amir_wp)

    # check with delivery notificatins enabled
    website.update_attributes!(notifications: WEBSITE_NOTIFY_DELIVERY)

    init_email_deliveries
    chat = run_send_request(client, translator, website, 1000)
    revision = chat.revision
    project = revision.project

    cms_request = revision.cms_request
    assert cms_request

    spanish = languages(:Spanish)
    german = languages(:German)

    # --- translator returns the completed translation

    # since the translator selected himself, there's no reason to send an email notification
    total_amount = 0

    check_emails_delivered(0)

    client_account = client.find_or_create_account(DEFAULT_CURRENCY_ID)

    # create a new version without any texts
    # ---------------- upload support files and a new version ------------------------
    # create a project file that includes the correct support file ID
    stream = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/blank_proj.xml", 'rb')
    support_file_ids = { 355 => 1 }
    listener = XmlRevisionChanger.new('Hotdog', 'veryfirst', revision.id, support_file_ids)
    parser = REXML::Parsers::StreamParser.new(stream, listener)
    parser.parse
    stream.close

    fullpath = "#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/produced_complete.xml.gz"
    Zlib::GzipWriter.open(fullpath) do |gz|
      gz.write(listener.result)
    end
    files_to_delete << fullpath

    session = login(translator)

    check_emails_delivered(0)
    trans_version_id = create_version(session, project.id, revision.id, 'sample/Initial/produced_complete.xml.gz', true, 1)
    check_emails_delivered(0)

    logout(session)

    # before upload, revision language completness is 0
    revision.revision_languages.each do |rl|
      assert_equal 100, rl.completed_percentage
    end

    get(url_for(controller: '/cms_requests', action: :show, website_id: website.id, id: cms_request.id, format: :xml, accesskey: website.accesskey))
    assert_response :success

    # indicate that TAS finished handling
    post url_for(controller: '/cms_requests', action: :notify_tas_done, website_id: website.id, id: cms_request.id, format: 'xml'),
         params: { accesskey: website.accesskey }
    assert_response :success

    cms_request.reload
    assert_not_nil cms_request.completed_at

    # check that the revision languages show 100% complete
    revision.revision_languages.each do |rl|
      assert_equal 100, rl.completed_percentage
    end

    # --- finalize the work and get paid
    session = login(translator)

    get(url_for(controller: '/chats', action: :show, project_id: chat.revision.project_id, revision_id: chat.revision_id, id: chat.id))
    assert_response :success

    account = translator.find_or_create_account(DEFAULT_CURRENCY_ID)
    translator_balance = account.balance
    root_account = RootAccount.first
    unless root_account
      root_account = RootAccount.create(balance: 0, currency_id: DEFAULT_CURRENCY_ID)
    end
    root_balance = root_account.balance

    chat.bids.each do |bid|
      bid_amount = bid.account.balance
      assert_not_equal 0, bid_amount

      cms_target_language = bid.chat.revision.cms_request.cms_target_languages.where('language_id=?', bid.revision_language.language.id).first
      assert cms_target_language

      xml_http_request(:post, url_for(controller: '/chats', action: :declare_done, project_id: chat.revision.project_id, revision_id: chat.revision_id, id: chat.id),
                       lang_id: bid.revision_language.language_id, bid_id: bid.id)
      assert_response :success

      cms_target_language.reload

      check_emails_delivered(0)

      assert_equal CMS_TARGET_LANGUAGE_TRANSLATED, cms_target_language.status

      bid.reload

      assert_equal BID_COMPLETED, bid.status
      assert_equal 0, bid.account.balance

      account.reload
      root_account.reload

      assert_same_amount(translator_balance + (bid_amount * (1 - FEE_RATE)), account.balance)
      assert_same_amount(root_balance + (bid_amount * FEE_RATE), root_account.balance)

      translator_balance = account.balance
      root_balance = root_account.balance

    end

    logout(session)

    files_to_delete.each { |file_to_delete| File.delete(file_to_delete) }

  end

  def test_send_with_review
    CmsRequest.destroy_all
    ManagedWork.delete_all
    PendingMoneyTransaction.delete_all

    files_to_delete = []

    client = users(:amir)
    WebMessage.delete_all

    translator = users(:orit)
    reviewer = users(:guy)
    website = websites(:amir_wp)

    spanish = languages(:Spanish)

    # create managed_work
    offer = website.website_translation_offers.where('to_language_id=?', spanish.id).first
    assert offer
    managed_work = ManagedWork.new(active: MANAGED_WORK_ACTIVE, translation_status: MANAGED_WORK_CREATED, notified: 0)
    managed_work.owner = offer
    managed_work.translator = reviewer
    assert managed_work.save

    init_email_deliveries
    chat = run_send_request(client, translator, website, 1000)
    revision = chat.revision
    project = revision.project

    cms_request = revision.cms_request
    assert cms_request

    # --- translator returns the completed translation

    # since the translator selected himself, there's no reason to send an email notification
    total_amount = 0

    check_emails_delivered(0)

    chat.bids.each do |bid|
      assert_equal BID_ACCEPTED, bid.status
      assert_equal 1, bid.won
      contract = website.website_translation_contracts.joins(:website_translation_offer).where('(website_translation_offers.from_language_id=?) AND (website_translation_offers.to_language_id=?) AND (website_translation_contracts.status=?)', revision.language_id, bid.revision_language.language_id, TRANSLATION_CONTRACT_ACCEPTED).first
      # offer = website.website_translation_offers.where('(from_language_id=?) AND (to_language_id=?)',revision.language_id, bid.revision_language.language_id).first
      assert contract
      assert_equal contract.amount, bid.amount
      assert_equal contract.currency, bid.currency

      # check that the bid has an account with the right sum
      assert bid.account
      expected_amount = contract.amount * revision.lang_word_count(bid.revision_language.language) * (1 + REVIEW_PRICE_PERCENTAGE) # including review fee
      assert expected_amount > 0
      assert_same_amount(expected_amount, bid.account.balance)

      total_amount += expected_amount

      managed_work = bid.revision_language.managed_work
      assert managed_work
      assert_equal MANAGED_WORK_ACTIVE, managed_work.active
      assert_equal MANAGED_WORK_CREATED, managed_work.translation_status
      assert_equal reviewer, managed_work.translator
    end

    client_account = client.find_or_create_account(DEFAULT_CURRENCY_ID)
    assert_equal 0, (client_account.pending_total_expenses[0] - client_account.hold_sum)

    # check that the project was assigned OK to the translator
    check_after_translator_assignment(client, translator, website, revision)

    # create a new version, all texts are completed
    # ---------------- upload support files and a new version ------------------------
    # create a project file that includes the correct support file ID
    stream = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/with_ignores/proj2_complete.xml", 'rb')
    support_file_ids = { 355 => 1 }
    listener = XmlRevisionChanger.new('Hotdog', 'veryfirst', revision.id, support_file_ids)
    parser = REXML::Parsers::StreamParser.new(stream, listener)
    parser.parse
    stream.close

    fullpath = "#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/produced_complete.xml.gz"
    Zlib::GzipWriter.open(fullpath) do |gz|
      gz.write(listener.result)
    end
    files_to_delete << fullpath

    session = login(translator)

    trans_version_id = create_version(session, project.id, revision.id, 'sample/Initial/produced_complete.xml.gz', true, 1)
    check_emails_delivered(0)

    logout(session)

    # --- also do the output store test here ---
    cms_request = website.cms_requests[-1]
    assert cms_request.cms_target_languages.length == 1

    fname = 'sample/support_files/styles.css.gz'
    fdata = fixture_file_upload(fname, 'application/octet-stream')

    cms_target_language = cms_request.cms_target_language
    multipart_post(url_for(controller: '/cms_requests', action: :store_output, website_id: website.id, id: cms_request.id,
                           format: :xml),
                   accesskey: website.accesskey, language_id: cms_target_language.language_id, cms_download: { uploaded_data: fdata, description: 'HTML output' })
    assert_response :success

    xml = get_xml_tree(@response.body)
    cms_download_id = get_element_attribute(xml.root.elements['result'], 'id').to_i
    cms_download = CmsDownload.find(cms_download_id)
    assert cms_download
    assert_equal cms_target_language, cms_download.cms_target_language

    # upload again, see that the file is only updated
    multipart_post(url_for(controller: '/cms_requests', action: :store_output, website_id: website.id, id: cms_request.id,
                           format: :xml),
                   accesskey: website.accesskey, language_id: cms_target_language.language_id, cms_download: { uploaded_data: fdata, description: 'HTML output' })
    assert_response :success

    cms_target_language.reload
    assert_equal 1, cms_target_language.cms_downloads.length

    xml = get_xml_tree(@response.body)
    cms_download_id = get_element_attribute(xml.root.elements['result'], 'id').to_i
    assert_not_equal cms_download_id, cms_download.id

    # before setting the title, it should be blank
    assert_nil cms_target_language.title

    # upload a second file, with a different description. Also, set the title
    title = "title for translation in #{cms_target_language.language.name}"
    multipart_post(url_for(controller: '/cms_requests', action: :store_output, website_id: website.id, id: cms_request.id,
                           format: :xml),
                   accesskey: website.accesskey, language_id: cms_target_language.language_id, title: title, cms_download: { uploaded_data: fdata, description: 'Meta data' })
    assert_response :success

    cms_target_language.reload
    assert_equal 2, cms_target_language.cms_downloads.length
    assert_equal title, cms_target_language.title

    # try to download the uploaded files
    ['HTML output', 'Meta data', nil, 'xxxx'].each do |description|
      get(url_for(controller: '/cms_requests', action: :cms_download, website_id: website.id, id: cms_request.id,
                  accesskey: website.accesskey, language: cms_target_language.language.name, description: description, format: :xml))
      assert_response :success

      xml = get_xml_tree(@response.body)
      # puts xml
      if description == 'xxxx'
        assert_element_text('cannot locate this download', xml.root.elements['status'])
      else
        cms_download_id = get_element_attribute(xml.root.elements['cms_download'], 'id').to_i
        cms_download = CmsDownload.find(cms_download_id)
        assert cms_download
        assert_equal cms_target_language, cms_download.cms_target_language
        assert_equal description, cms_download.description if description
      end
    end
    get(url_for(controller: '/cms_requests', action: :cms_download, website_id: website.id, id: cms_request.id,
                accesskey: website.accesskey, language: 'problem language', format: :xml))
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_text('cannot find this language', xml.root.elements['status'])

    get(url_for(controller: '/cms_requests', action: :cms_download, website_id: website.id, id: cms_request.id,
                accesskey: website.accesskey, language: 'French', format: :xml))
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_text('cannot locate this output language', xml.root.elements['status'])

    get(url_for(controller: '/cms_requests', action: :show, website_id: website.id, id: cms_request.id, format: :xml, accesskey: website.accesskey))
    assert_response :success

    cms_request.reload

    # update the permlink to the translations
    cms_target_language = cms_request.cms_target_language
    permlink = "link-to-translated-post-#{cms_target_language.language.name}"
    post url_for(controller: '/cms_requests', action: :update_permlink, website_id: website.id, id: cms_request.id, format: :xml),
         params: { accesskey: website.accesskey, language: cms_target_language.language.name, permlink: permlink }
    assert_response :success
    cms_target_language.reload
    assert_equal permlink, cms_target_language.permlink
    xml = get_xml_tree(@response.body)
    assert_element_attribute('Permlink updated', xml.root.elements['result'], 'message')
    assert_element_attribute(permlink, xml.root.elements['result'], 'permlink')

    # --- update the original language permlink
    permlink = 'link-to-original-post'
    post url_for(controller: '/cms_requests', action: :update_permlink, website_id: website.id, id: cms_request.id, format: :xml),
         params: { accesskey: website.accesskey, permlink: permlink }
    assert_response :success
    cms_request.reload
    assert_equal permlink, cms_request.permlink
    xml = get_xml_tree(@response.body)
    assert_element_attribute('Permlink updated', xml.root.elements['result'], 'message')
    assert_element_attribute(permlink, xml.root.elements['result'], 'permlink')

    get(url_for(controller: '/websites', action: :links, id: website.id, format: :xml, accesskey: website.accesskey))
    assert_response :success

    link_map = assigns(:link_map)
    assert link_map
    assert !link_map.keys.empty?
    assert_equal cms_request, link_map.keys[0]

    # check with delivery notificatins enabled
    website.update_attributes!(notifications: WEBSITE_NOTIFY_DELIVERY)

    # indicate that TAS finished handling
    post url_for(controller: '/cms_requests', action: :notify_tas_done, website_id: website.id, id: cms_request.id, format: 'xml'),
         params: { accesskey: website.accesskey }
    assert_response :success

    cms_request.reload
    assert_not_nil cms_request.completed_at

    website.update_attributes!(notifications: 0)

    # --- finalize the work and get paid
    session = login(translator)

    get(url_for(controller: '/chats', action: :show, project_id: chat.revision.project_id, revision_id: chat.revision_id, id: chat.id))
    assert_response :success

    account = translator.find_or_create_account(DEFAULT_CURRENCY_ID)
    translator_balance = account.balance
    root_account = RootAccount.first
    unless root_account
      root_account = RootAccount.create(balance: 0, currency_id: DEFAULT_CURRENCY_ID)
    end
    root_balance = root_account.balance

    chat.bids.each do |bid|
      bid_amount = bid.account.balance
      assert_not_equal 0, bid_amount

      cms_target_language = bid.chat.revision.cms_request.cms_target_languages.where('language_id=?', bid.revision_language.language.id).first
      assert cms_target_language

      xml_http_request(:post, url_for(controller: '/chats', action: :declare_done, project_id: chat.revision.project_id, revision_id: chat.revision_id, id: chat.id),
                       lang_id: bid.revision_language.language_id, bid_id: bid.id)
      assert_response :success

      cms_target_language.reload

      bid.reload
      managed_work = bid.revision_language.managed_work
      assert_equal MANAGED_WORK_ACTIVE, managed_work.active

      if bid.revision_language.language == spanish
        expected_status = CMS_TARGET_LANGUAGE_TRANSLATED

        assert_equal MANAGED_WORK_REVIEWING, managed_work.translation_status
        assert_equal reviewer, managed_work.translator
      else
        assert false
      end
      assert_equal expected_status, cms_target_language.status

      if bid.revision_language.language == spanish
        check_emails_delivered(1) # the reviewer is notified

        assert_equal BID_COMPLETED, bid.status
        assert_same_amount(chat.revision.reviewer_payment(bid), bid.account.balance)

        account.reload
        root_account.reload

        translator_payment = chat.revision.translator_payment(bid)

        assert_same_amount(translator_balance + (translator_payment * (1 - FEE_RATE)), account.balance)
        assert_same_amount(root_balance + (translator_payment * FEE_RATE), root_account.balance)

        translator_balance = account.balance
        root_balance = root_account.balance

        expected_status = CMS_TARGET_LANGUAGE_TRANSLATED

        assert_equal MANAGED_WORK_REVIEWING, managed_work.translation_status

      else
        check_emails_delivered(0) # no need to notify anyone yet

        assert_equal BID_ACCEPTED, bid.status
        expected_status = CMS_TARGET_LANGUAGE_ASSIGNED

        assert_equal MANAGED_WORK_CREATED, managed_work.translation_status # if the work didn't complete yet, no need to review
      end
      assert_equal expected_status, cms_target_language.status

      if expected_status == CMS_TARGET_LANGUAGE_TRANSLATED
        # make sure that the bid starts completed
        assert_equal BID_COMPLETED, bid.status
      end
    end

    logout(session)

    # ---- reviewer completes the review ----

    session = login(reviewer)

    money_account = reviewer.find_or_create_account(DEFAULT_CURRENCY_ID)
    reviewer_balance = money_account.balance

    reviewed_something = false

    chat.bids.each do |bid|

      next unless bid.status == BID_COMPLETED

      # check that the reviewer can access
      get(url_for(controller: '/chats', action: :show, project_id: chat.revision.project_id, revision_id: chat.revision_id, id: chat.id))
      assert_response :success

      assert assigns('is_reviewer')

      xml_http_request(:post, url_for(controller: '/chats', action: :review_complete, project_id: project.id, revision_id: revision.id, id: chat.id, bid_id: bid.id))
      assert_response :success

      check_emails_delivered(0)

      # finalize selected bids
      accept_list = {}
      idx = 1
      ChatsController::BID_REVIEW_CONDITIONS.each do
        accept_list[idx] = '1'
        idx += 1
      end
      assert_no_difference('bid.account.balance') do
        xml_http_request(:post, url_for(controller: '/chats', action: :finalize_review, project_id: project.id, revision_id: revision.id, id: chat.id),
                         accept: accept_list, bid_id: bid.id)
        assert_response :success
        assert_nil assigns(:warning)
      end
      revision.cms_request.reload
      assert_not_nil revision.cms_request.completed_at

      bid.revision_language.managed_work.reload
      assert_equal MANAGED_WORK_COMPLETE, bid.revision_language.managed_work.translation_status

      reviewed_something = true
    end

    assert reviewed_something

    logout(session)

    files_to_delete.each { |file_to_delete| File.delete(file_to_delete) }

  end

  def test_same_translator_and_reviewer
    CmsRequest.destroy_all
    ManagedWork.delete_all
    PendingMoneyTransaction.delete_all

    files_to_delete = []

    client = users(:amir)
    WebMessage.delete_all

    translator = users(:orit)
    website = websites(:amir_wp)

    spanish = languages(:Spanish)

    # create managed_work
    offer = website.website_translation_offers.where('to_language_id=?', spanish.id).first
    assert offer
    managed_work = ManagedWork.new(active: MANAGED_WORK_ACTIVE, translation_status: MANAGED_WORK_CREATED, notified: 0)
    managed_work.owner = offer
    managed_work.translator = translator
    assert managed_work.save

    init_email_deliveries
    chat = run_send_request(client, translator, website, 1000)
    revision = chat.revision
    project = revision.project

    cms_request = revision.cms_request
    assert cms_request

    # --- translator returns the completed translation

    # since the translator selected himself, there's no reason to send an email notification
    total_amount = 0

    check_emails_delivered(0)

    chat.bids.each do |bid|
      assert_equal BID_ACCEPTED, bid.status
      assert_equal 1, bid.won

      contract = website.website_translation_contracts.joins(:website_translation_offer).where('(website_translation_offers.from_language_id=?) AND (website_translation_offers.to_language_id=?) AND (website_translation_contracts.status=?)', revision.language_id, bid.revision_language.language_id, TRANSLATION_CONTRACT_ACCEPTED).first
      assert contract
      assert_equal contract.amount, bid.amount
      assert_equal contract.currency, bid.currency

      # check that the bid has an account with the right sum
      assert bid.account
      expected_amount = contract.amount * revision.lang_word_count(bid.revision_language.language) # no review fee
      assert expected_amount > 0
      assert_same_amount(expected_amount, bid.account.balance)

      total_amount += expected_amount

      managed_work = bid.revision_language.managed_work
      assert managed_work
      assert_equal MANAGED_WORK_INACTIVE, managed_work.active
      assert_equal MANAGED_WORK_CREATED, managed_work.translation_status
      assert_nil managed_work.translator
    end

    client_account = client.find_or_create_account(DEFAULT_CURRENCY_ID)
    assert_equal 0, (client_account.pending_total_expenses[0] - client_account.hold_sum)

    # check that the project was assigned OK to the translator
    check_after_translator_assignment(client, translator, website, revision)

    # create a new version, all texts are completed
    # ---------------- upload support files and a new version ------------------------
    # create a project file that includes the correct support file ID
    stream = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/with_ignores/proj2_complete.xml", 'rb')
    support_file_ids = { 355 => 1 }
    listener = XmlRevisionChanger.new('Hotdog', 'veryfirst', revision.id, support_file_ids)
    parser = REXML::Parsers::StreamParser.new(stream, listener)
    parser.parse
    stream.close

    fullpath = "#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/produced_complete.xml.gz"
    Zlib::GzipWriter.open(fullpath) do |gz|
      gz.write(listener.result)
    end
    files_to_delete << fullpath

    session = login(translator)

    # CmsRequest satus changes from 4 (CMS_REQUEST_RELEASED_TO_TRANSLATORS) to 5 (CMS_REQUEST_TRANSLATED) here
    trans_version_id = create_version(session, project.id, revision.id, 'sample/Initial/produced_complete.xml.gz', true, 1)

    check_emails_delivered(0)

    logout(session)

    # --- also do the output store test here ---
    cms_request = website.cms_requests[-1]
    assert cms_request.cms_target_languages.length == 1

    fname = 'sample/support_files/styles.css.gz'
    fdata = fixture_file_upload(fname, 'application/octet-stream')

    cms_target_language = cms_request.cms_target_language
    multipart_post(url_for(controller: '/cms_requests', action: :store_output, website_id: website.id, id: cms_request.id,
                           format: :xml),
                   accesskey: website.accesskey, language_id: cms_target_language.language_id, cms_download: { uploaded_data: fdata, description: 'HTML output' })
    assert_response :success

    xml = get_xml_tree(@response.body)
    cms_download_id = get_element_attribute(xml.root.elements['result'], 'id').to_i
    cms_download = CmsDownload.find(cms_download_id)
    assert cms_download
    assert_equal cms_target_language, cms_download.cms_target_language

    # upload again, see that the file is only updated
    multipart_post(url_for(controller: '/cms_requests', action: :store_output, website_id: website.id, id: cms_request.id,
                           format: :xml),
                   accesskey: website.accesskey, language_id: cms_target_language.language_id, cms_download: { uploaded_data: fdata, description: 'HTML output' })
    assert_response :success

    cms_target_language.reload
    assert_equal 1, cms_target_language.cms_downloads.length

    xml = get_xml_tree(@response.body)
    cms_download_id = get_element_attribute(xml.root.elements['result'], 'id').to_i
    assert_not_equal cms_download_id, cms_download.id

    # before setting the title, it should be blank
    assert_nil cms_target_language.title

    # upload a second file, with a different description. Also, set the title
    title = "title for translation in #{cms_target_language.language.name}"
    multipart_post(url_for(controller: '/cms_requests', action: :store_output, website_id: website.id, id: cms_request.id,
                           format: :xml),
                   accesskey: website.accesskey, language_id: cms_target_language.language_id, title: title, cms_download: { uploaded_data: fdata, description: 'Meta data' })
    assert_response :success

    cms_target_language.reload
    assert_equal 2, cms_target_language.cms_downloads.length
    assert_equal title, cms_target_language.title

    # try to download the uploaded files
    ['HTML output', 'Meta data', nil, 'xxxx'].each do |description|
      get(url_for(controller: '/cms_requests', action: :cms_download, website_id: website.id, id: cms_request.id,
                  accesskey: website.accesskey, language: cms_target_language.language.name, description: description, format: :xml))
      assert_response :success

      xml = get_xml_tree(@response.body)
      # puts xml
      if description == 'xxxx'
        assert_element_text('cannot locate this download', xml.root.elements['status'])
      else
        cms_download_id = get_element_attribute(xml.root.elements['cms_download'], 'id').to_i
        cms_download = CmsDownload.find(cms_download_id)
        assert cms_download
        assert_equal cms_target_language, cms_download.cms_target_language
        assert_equal description, cms_download.description if description
      end
    end
    get(url_for(controller: '/cms_requests', action: :cms_download, website_id: website.id, id: cms_request.id,
                accesskey: website.accesskey, language: 'problem language', format: :xml))
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_text('cannot find this language', xml.root.elements['status'])

    get(url_for(controller: '/cms_requests', action: :cms_download, website_id: website.id, id: cms_request.id,
                accesskey: website.accesskey, language: 'French', format: :xml))
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_text('cannot locate this output language', xml.root.elements['status'])

    get(url_for(controller: '/cms_requests', action: :show, website_id: website.id, id: cms_request.id, format: :xml, accesskey: website.accesskey))
    assert_response :success

    cms_request.reload

    # update the permlink to the translations
    cms_target_language = cms_request.cms_target_language
    permlink = "link-to-translated-post-#{cms_target_language.language.name}"
    post url_for(controller: '/cms_requests', action: :update_permlink, website_id: website.id, id: cms_request.id, format: :xml),
         params: { accesskey: website.accesskey, language: cms_target_language.language.name, permlink: permlink }
    assert_response :success
    cms_target_language.reload
    assert_equal permlink, cms_target_language.permlink
    xml = get_xml_tree(@response.body)
    assert_element_attribute('Permlink updated', xml.root.elements['result'], 'message')
    assert_element_attribute(permlink, xml.root.elements['result'], 'permlink')

    # --- update the original language permlink
    permlink = 'link-to-original-post'
    post url_for(controller: '/cms_requests', action: :update_permlink, website_id: website.id, id: cms_request.id, format: :xml),
         params: { accesskey: website.accesskey, permlink: permlink }
    assert_response :success
    cms_request.reload
    assert_equal permlink, cms_request.permlink
    xml = get_xml_tree(@response.body)
    assert_element_attribute('Permlink updated', xml.root.elements['result'], 'message')
    assert_element_attribute(permlink, xml.root.elements['result'], 'permlink')

    get(url_for(controller: '/websites', action: :links, id: website.id, format: :xml, accesskey: website.accesskey))
    assert_response :success

    link_map = assigns(:link_map)
    assert link_map
    assert !link_map.keys.empty?
    assert_equal cms_request, link_map.keys[0]

    # check with delivery notificatins enabled
    website.update_attributes!(notifications: WEBSITE_NOTIFY_DELIVERY)

    # indicate that TAS finished handling
    post url_for(controller: '/cms_requests', action: :notify_tas_done, website_id: website.id, id: cms_request.id, format: 'xml'),
         params: { accesskey: website.accesskey }
    assert_response :success

    cms_request.reload
    assert_not_nil cms_request.completed_at

    website.update_attributes!(notifications: 0)

    # --- finalize the work and get paid
    session = login(translator)

    get(url_for(controller: '/chats', action: :show, project_id: chat.revision.project_id, revision_id: chat.revision_id, id: chat.id))
    assert_response :success

    account = translator.find_or_create_account(DEFAULT_CURRENCY_ID)
    translator_balance = account.balance
    root_account = RootAccount.first
    unless root_account
      root_account = RootAccount.create(balance: 0, currency_id: DEFAULT_CURRENCY_ID)
    end
    root_balance = root_account.balance

    chat.bids.each do |bid|
      bid_amount = bid.account.balance
      assert_not_equal 0, bid_amount

      cms_target_language = bid.chat.revision.cms_request.cms_target_languages.where('language_id=?', bid.revision_language.language.id).first
      assert cms_target_language

      xml_http_request(:post, url_for(controller: '/chats', action: :declare_done, project_id: chat.revision.project_id, revision_id: chat.revision_id, id: chat.id),
                       lang_id: bid.revision_language.language_id, bid_id: bid.id)
      assert_response :success

      cms_target_language.reload

      bid.reload
      managed_work = bid.revision_language.managed_work
      assert_equal MANAGED_WORK_INACTIVE, managed_work.active

      if bid.revision_language.language == spanish
        expected_status = CMS_TARGET_LANGUAGE_TRANSLATED

        assert_equal MANAGED_WORK_WAITING_FOR_REVIEWER, managed_work.translation_status
        assert_nil managed_work.translator
      else
        assert false
      end
      assert_equal expected_status, cms_target_language.status

      if bid.revision_language.language == spanish
        check_emails_delivered(0) # no reviewer to notify

        assert_equal BID_COMPLETED, bid.status
        assert_same_amount(0, bid.account.balance)

        account.reload
        root_account.reload

        translator_payment = chat.revision.translator_payment(bid)

        assert_same_amount(translator_balance + (translator_payment * (1 - FEE_RATE)), account.balance)
        assert_same_amount(root_balance + (translator_payment * FEE_RATE), root_account.balance)

        translator_balance = account.balance
        root_balance = root_account.balance

        expected_status = CMS_TARGET_LANGUAGE_TRANSLATED

        assert_equal MANAGED_WORK_WAITING_FOR_REVIEWER, managed_work.translation_status

      else
        check_emails_delivered(0) # no need to notify anyone yet

        assert_equal BID_ACCEPTED, bid.status
        expected_status = CMS_TARGET_LANGUAGE_ASSIGNED

        assert_equal MANAGED_WORK_CREATED, managed_work.translation_status # if the work didn't complete yet, no need to review
      end
      assert_equal expected_status, cms_target_language.status

      if expected_status == CMS_TARGET_LANGUAGE_TRANSLATED
        # make sure that the bid starts completed
        assert_equal BID_COMPLETED, bid.status
      end
    end

    logout(session)

    files_to_delete.each { |file_to_delete| File.delete(file_to_delete) }

  end

  def test_duplicate_complete
    CmsRequest.destroy_all
    ManagedWork.delete_all
    PendingMoneyTransaction.delete_all

    files_to_delete = []

    client = users(:amir)
    translator = users(:orit)
    website = websites(:amir_wp)

    init_email_deliveries
    chat = run_send_request(client, translator, website, 1000)
    revision = chat.revision
    project = revision.project

    spanish = languages(:Spanish)
    german = languages(:German)

    # since the translator selected himself, there's no reason to send an email notification
    check_emails_delivered(0)

    chat.bids.each do |bid|
      assert_equal BID_ACCEPTED, bid.status
      assert_equal 1, bid.won
      contract = website.
                 website_translation_contracts.
                 includes(:website_translation_offer).
                 where('(website_translation_offers.from_language_id=?) AND (website_translation_offers.to_language_id=?) AND (website_translation_contracts.status=?)',
                       revision.language_id,
                       bid.revision_language.language_id,
                       TRANSLATION_CONTRACT_ACCEPTED).first

      assert contract
      assert_equal contract.amount, bid.amount
      assert_equal contract.currency, bid.currency

      # check that the bid has an account with the right sum
      assert bid.account
      expected_amount = contract.amount * revision.lang_word_count(bid.revision_language.language)
      assert expected_amount > 0
      assert_same_amount(expected_amount, bid.account.balance)
    end

    # check that the project was assigned OK to the translator
    check_after_translator_assignment(client, translator, website, revision)

    session = login(translator)

    assert_equal 1, revision.versions.length
    version = revision.versions[0]
    assert_equal client, version.normal_user

    post(url_for(controller: '/versions', action: :duplicate_complete, project_id: project.id, revision_id: revision.id, id: version.id))
    assert_response :redirect

    result = assigns('result')
    assert result.key?('message')
    assert_equal result['message'], 'Version created'

    revision.reload

    assert_equal 2, revision.versions.length
    tx_version = revision.versions[-1]
    assert_equal translator, tx_version.normal_user
    assert_equal result['id'], tx_version.id

    tas_completion_notification_sent = assigns('tas_completion_notification_sent')
    assert_equal 1, tas_completion_notification_sent.length # notification for both Spanish

    logout(session)

  end

  def test_complete_by_cms
    client = users(:amir)
    translator = users(:orit)
    website = websites(:amir_wp)

    init_email_deliveries

    fnames = ['sample/support_files/styles.css.gz', 'sample/support_files/images/bluebottom.gif.gz']

    orig_language = languages(:English)
    translation_languages = [languages(:Spanish)]

    cms_request, project, revision, ts = create_cms_request(client, fnames, orig_language, translation_languages, website, nil, nil)

    post url_for(controller: '/cms_requests', action: :debug_complete, website_id: website.id, id: cms_request.id, format: 'xml'),
         params: { translator_id: translator.id, accesskey: website.accesskey }
    assert_response :success

    result = assigns('result')
    assert result
    assert result.key?('message')
    assert_equal result['message'], 'Completed the new version OK'

    cms_request.reload

    cms_target_language = cms_request.cms_target_language
    assert_equal CMS_TARGET_LANGUAGE_TRANSLATED, cms_target_language.status

    tas_completion_notification_sent = assigns('tas_completion_notification_sent')
    assert_equal translation_languages.length, tas_completion_notification_sent.length # notifications for both Spanish and German
  end

  def test_flush_stuck_request
    client = users(:amir)
    website = websites(:amir_wp)

    fnames = ['sample/support_files/styles.css.gz', 'sample/support_files/images/bluebottom.gif.gz']

    orig_language = languages(:English)
    translation_languages = [languages(:Spanish)]

    cms_request = create_cms_request(client, fnames, orig_language, translation_languages, website, nil, nil, true)

    assert_equal 1, cms_request.pending_tas
    assert_equal LAST_TAS_COMMAND_CREATE, cms_request.last_operation

    assert cms_request

    # put back the update time in order to check that it's really updated later
    CmsRequest.record_timestamps = false
    cms_request.updated_at = Time.now - 10
    CmsRequest.record_timestamps = true

    orig_cms_update_time = cms_request.updated_at

    checker = PeriodicChecker.new(Time.now + (TAS_PROCESSING_TIME + 1))
    cnt = checker.flush_cms_requests

    cms_request.reload
    assert_not_equal orig_cms_update_time, cms_request.updated_at
  end

  def test_send_and_assign_selftrans
    client = users(:amir)
    translator = users(:orit)
    website = websites(:amir_drupal_selftrans)

    spanish = languages(:Spanish)

    init_email_deliveries

    [0, 1].each do |free_usage|
      CmsRequest.destroy_all
      UserSession.destroy_all
      ManagedWork.delete_all
      PendingMoneyTransaction.delete_all
      MoneyAccount.delete_all

      root_account = RootAccount.first
      unless root_account
        root_account = RootAccount.create!(balance: 0, currency_id: DEFAULT_CURRENCY_ID)
      end

      account = client.find_or_create_account(DEFAULT_CURRENCY_ID)

      website.update_attributes!(free_usage: free_usage)

      root_balance = root_account.balance

      chat = run_send_request(client, translator, website, 1000, false, [spanish])
      revision = chat.revision
      project = revision.project

      # since the translator selected himself, there's no reason to send an email notification
      check_emails_delivered(0)

      assert_equal 1, chat.bids.length

      chat.bids.each do |bid|
        assert_equal BID_ACCEPTED, bid.status
        assert_equal 1, bid.won

        contract = website.website_translation_contracts.joins(:website_translation_offer).where('(website_translation_offers.from_language_id=?) AND (website_translation_offers.to_language_id=?) AND (website_translation_contracts.status=?)', revision.language_id, bid.revision_language.language_id, TRANSLATION_CONTRACT_ACCEPTED).first
        assert contract
        assert_equal contract.amount, bid.amount
        assert_equal contract.currency, bid.currency

        # check that the bid has an account with the right sum
        assert bid.account
        assert_same_amount(0, bid.account.balance)
      end

      # Should be free (zero cost)
    end

  end

  def test_send_and_assign_updates
    client = users(:amir)
    translator = users(:orit)
    website = websites(:amir_drupal_selftrans)

    spanish = languages(:Spanish)

    init_email_deliveries

    website.update_attributes!(free_usage: 0)

    project = nil
    revision = nil
    is_update = false
    for update_request in 0..1
      UserSession.destroy_all
      ManagedWork.delete_all

      account = client.find_or_create_account(DEFAULT_CURRENCY_ID)

      root_account = RootAccount.first
      unless root_account
        root_account = RootAccount.create!(balance: 0, currency_id: DEFAULT_CURRENCY_ID)
      end

      root_balance = root_account.balance

      chat = run_send_request(client, translator, website, 1000, false, nil, project)

      revision = chat.revision

      # if there already is a project, keep using it. Otherwise, initialize
      if project
        is_update = true
      else
        project = revision.project
        is_update = false
      end

      cms_request = revision.cms_request

      # since the translator selected himself, there's no reason to send an email notification
      check_emails_delivered(0)

      assert_equal 1, chat.bids.length

      chat.bids.each do |bid|
        assert_equal BID_ACCEPTED, bid.status
        assert_equal 1, bid.won
        contract = website.website_translation_contracts.joins(:website_translation_offer).where('(website_translation_offers.from_language_id=?) AND (website_translation_offers.to_language_id=?) AND (website_translation_contracts.status=?)', revision.language_id, bid.revision_language.language_id, TRANSLATION_CONTRACT_ACCEPTED).first
        assert contract
        assert_equal contract.amount, bid.amount
        assert_equal contract.currency, bid.currency

        # check that the bid has an account with the right sum
        assert bid.account
        assert_same_amount(0, bid.account.balance)
      end

      # Should be free (zero cost)
    end
  end

  def test_send_and_assign_with_low_balance
    skip 'The code that sends e-mails and this test must both be updated (see icldev-2690)'

    CmsRequest.destroy_all
    ManagedWork.delete_all
    WebMessage.delete_all
    PendingMoneyTransaction.delete_all

    client = users(:amir)
    translator = users(:orit)
    website = websites(:amir_wp)
    account = client.find_or_create_account(DEFAULT_CURRENCY_ID)

    init_email_deliveries

    checker = PeriodicChecker.new(Time.now)
    cnt = checker.alert_client_about_low_funding
    assert_equal 0, cnt
    check_emails_delivered(0)

    chat = run_send_request(client, translator, website, 0)
    assert_nil chat

    assert_equal 1, CmsRequest.count

    cms_request = CmsRequest.all.to_a[-1]
    assert cms_request

    # verify that the cms request didn't get assiged or change state
    cms_target_language = cms_request.cms_target_language
    assert_equal CMS_TARGET_LANGUAGE_CREATED, cms_target_language.status
    assert_nil cms_target_language.translator

    cnt = checker.alert_client_about_low_funding
    assert_equal 1, cnt
    check_emails_delivered(1)

    missing_balance, pending_cms_target_languages, pending_web_messages = account.pending_total_expenses
    assert missing_balance > 0

    # the message will not be sent again until something changes
    cnt = checker.alert_client_about_low_funding
    assert_equal 0, cnt
    check_emails_delivered(0)

    account.reload
    account.update_attributes(balance: (missing_balance - 1), warning_signature: nil)

    cnt = checker.alert_client_about_low_funding
    assert_equal 1, cnt
    check_emails_delivered(1)

    account.reload
    account.update_attributes(balance: missing_balance, warning_signature: nil)

    cnt = checker.alert_client_about_low_funding
    assert_equal 0, cnt
    check_emails_delivered(0)
  end

  def test_send_and_cancel
    CmsRequest.destroy_all
    ManagedWork.delete_all
    Arbitration.delete_all
    ArbitrationOffer.delete_all
    PendingMoneyTransaction.delete_all

    client = users(:amir)
    translator = users(:orit)
    website = websites(:amir_wp)

    assert_equal 0, translator.pending_cms_chats.length

    orig_invoices = client.invoices.length

    init_email_deliveries
    chat = run_send_request(client, translator, website, 1000)
    revision = chat.revision
    project = revision.project

    check_emails_delivered(0)

    translator.clear_cache
    assert_equal 1, translator.pending_cms_chats.length

    # --- do the arbitration now ---

    # log in as a supporter
    supporter = users(:supporter)
    ssession = login(supporter)

    session = login(client)
    xsession = login(translator)

    # ----------- put the bid into arbitration --------------
    init_email_deliveries

    chat.bids.each do |bid|

      # view the bid
      get url_for(controller: '/bids', action: :show, project_id: project.id, revision_id: revision.id, chat_id: chat.id, id: bid.id),
          params: { session: xsession }
      assert_response :success

      # request an arbitration
      get url_for(controller: '/arbitrations', action: :new),
          params: {
            session: xsession, bid_id: bid.id, kind: 'bid'
          }
      assert_response :success

      post url_for(controller: '/arbitrations', action: :request_cancel_bid),
           params: { session: xsession },
           xhr: true
      assert_response :success

      # submit, with complete data
      reason = 'Fed up with this system. Please help!'
      post url_for(controller: '/arbitrations', action: :create_cancel_bid_arbitration),
           params: { :session => xsession, 'how_to_handle' => 'supporter', 'reason' => reason },
           xhr: true
      assert_response :success
      assert_nil assigns(:warning)

      check_emails_delivered(2)

      # find the created arbitration
      arbitration = bid.arbitration
      assert arbitration

      assert_equal arbitration.messages.length, 1
      message = arbitration.messages[-1]
      assert_equal message.body, reason

      # view the arbitration
      get url_for(controller: '/arbitrations', action: :show, id: arbitration.id),
          params: { session: xsession }
      assert_response :success

      # see that we can post messages
      assert_select 'table#reply'

      get url_for(controller: '/arbitrations', action: :show, id: arbitration.id),
          params: { session: session }
      assert_response :success

      # see that we can post messages
      assert_select 'table#reply'

      post url_for(controller: '/arbitrations', action: :assign_to_supporter, id: arbitration.id, format: :js),
           params: { session: ssession }
      assert_response :success
      arbitration.reload
      assert_equal arbitration.supporter_id, supporter.id

      # -------------- translator side ---------------
      bid_payment = bid.account.balance

      # locate the translator and client account
      xlat_account = translator.money_accounts[0]
      client_account = client.money_accounts[0]
      prev_xlat_balance =
        if xlat_account
          xlat_account.balance
        else
          0
        end

      prev_client_balance =
        if client_account
          client_account.balance
        else
          0
        end

      # open the ruling dialog
      xml_http_request(:post, url_for(controller: '/arbitrations', action: :edit_ruling, id: arbitration.id),
                       :session => ssession, 'req' => 'show')
      assert_response :success

      # save the ruling
      pay_amount = bid.account.balance / 2
      xml_http_request(:post, url_for(controller: '/arbitrations', action: :edit_ruling, id: arbitration.id),
                       session: ssession, ruling: { amount: pay_amount })
      assert_response :success
      assert_equal 1, arbitration.arbitration_offers.count

      offer = ArbitrationOffer.first
      assert offer
      assert_equal OFFER_ACCEPTED, offer.status

      check_emails_delivered(2)

      # see that the payment had completed and refund made to the rest of the money
      client.reload
      translator.reload
      xlat_account = translator.money_accounts[0]
      client_account = client.money_accounts[0]
      client_account.reload
      offer.reload
      revision.reload
      arbitration.reload
      bid.reload

      assert_equal OFFER_ACCEPTED, offer.status
      # The bid status must be reset so another translator can take the job,
      # complete it and get paid.
      assert_equal BID_GIVEN, bid.status
      assert_equal ARBITRATION_CLOSED, arbitration.status

      assert_equal 0, bid.account.balance
      assert_same_amount(prev_xlat_balance + pay_amount * (1 - FEE_RATE), xlat_account.balance)
      assert_same_amount(prev_client_balance + (bid_payment - pay_amount), client_account.balance)

      # see that both client and translators cannot post anymore
      get url_for(controller: '/arbitrations', action: :show, id: arbitration.id),
          params: { session: session }
      assert_response :success
      assert_select 'table#reply', false

      get url_for(controller: '/arbitrations', action: :show, id: arbitration.id),
          params: { session: xsession }
      assert_response :success
      assert_select 'table#reply', false

      # view the arbitration by the supporter
      get url_for(controller: '/arbitrations', action: :show, id: arbitration.id),
          params: { session: ssession }
      assert_response :success

      check_client_pages(client, session)
      check_translator_pages(translator, xsession, false)

      check_emails_delivered(0)
    end

    # after the arbitration is done, make sure that the translator doesn't still need to complete this work
    translator.clear_cache
    assert_equal 0, translator.pending_cms_chats.length

    revision.reload
    revision.revision_languages.each do |rl|
      assert_nil rl.selected_bid
    end

    # see that we can assign it to a different translator
    newbi = users(:newbi)
    chat = run_send_request(client, newbi, website, 1000, true, nil, nil, true, false)
    assert chat

    # --- and, again, make sure it's all OK ---
    chat.bids.each do |bid|
      assert_equal BID_ACCEPTED, bid.status
      assert_equal 1, bid.won

      contract = website.website_translation_contracts.joins(:website_translation_offer).where('(website_translation_offers.from_language_id=?) AND (website_translation_offers.to_language_id=?) AND (website_translation_contracts.status=?)', revision.language_id, bid.revision_language.language_id, TRANSLATION_CONTRACT_ACCEPTED).first
      assert contract
      assert_equal contract.amount, bid.amount
      assert_equal contract.currency, bid.currency

    end
    client.reload
  end

  def test_send_and_assign_from_new_balance
    CmsRequest.destroy_all
    ManagedWork.delete_all
    PendingMoneyTransaction.delete_all

    client = users(:amir)
    translator = users(:orit)
    website = websites(:amir_wp)

    client_account = client.find_or_create_account(DEFAULT_CURRENCY_ID)
    client_account.update_attributes(balance: 0)

    orig_invoices = client.invoices.length

    init_email_deliveries
    chat = run_send_request(client, translator, website, 0)
    assert_nil chat

    # --- add money to the client's account and try to assign the project again to the same translator
    client_account.reload
    client_account.update_attributes(balance: 1000)

    chat = run_send_request(client, translator, website, 1000, true)
    revision = chat.revision
    project = revision.project

    # since the translator selected himself, there's no reason to send an email notification
    check_emails_delivered(0)

    chat.bids.each do |bid|
      assert_equal BID_ACCEPTED, bid.status
      assert_equal 1, bid.won
      contract = website.website_translation_contracts.joins(:website_translation_offer).where('(website_translation_offers.from_language_id=?) AND
                                                                                                 (website_translation_offers.to_language_id=?) AND
                                                                                                 (website_translation_contracts.status=?)',
                                                                                               revision.language_id, bid.revision_language.language_id, TRANSLATION_CONTRACT_ACCEPTED).first
      assert contract
      assert_equal contract.amount, bid.amount
      assert_equal contract.currency, bid.currency

      # check that the bid has an account with the right sum
      assert bid.account
      expected_amount = contract.amount * revision.lang_word_count(bid.revision_language.language)
      assert expected_amount > 0
      assert_same_amount(expected_amount, bid.account.balance)
    end

    # do final checks
    check_after_translator_assignment(client, translator, website, revision)
  end

  def test_destroy_requests
    client = users(:amir)
    website = websites(:amir_drupal_rpc)

    fnames = ['sample/support_files/styles.css.gz']

    orig_language = languages(:English)
    translation_languages = [languages(:Spanish)]

    # create a request and delete with as the remote server
    cms_request = create_cms_request_plain(client, fnames, orig_language, translation_languages, website, 'page', nil)
    cms_request.update_attributes(status: CMS_REQUEST_RELEASED_TO_TRANSLATORS, pending_tas: 0)

    assert cms_request
    assert_equal true, cms_request.can_cancel?

    cms_request_id = cms_request.id

    delete(url_for(controller: '/cms_requests', action: :destroy, website_id: cms_request.website.id, id: cms_request.id,
                   format: :xml), accesskey: cms_request.website.accesskey)
    assert_response :success

    xml = get_xml_tree(@response.body)
    assert_element_attribute(0.to_s, xml.root.elements['status'], 'err_code')
    assert_element_attribute('Deleted', xml.root.elements['result'], 'message')

    reloaded = CmsRequest.where('id=?', cms_request_id).first
    assert_nil reloaded

    # this one will not be deleted, because translation has already started
    cms_request = create_cms_request_plain(client, fnames, orig_language, translation_languages, website, 'page', nil)
    assert cms_request

    cms_request.update_attributes(status: CMS_REQUEST_RELEASED_TO_TRANSLATORS, pending_tas: 0)
    tl = cms_request.cms_target_languages.first
    assert tl
    tl.update_attributes(status: CMS_TARGET_LANGUAGE_ASSIGNED)

    assert_equal false, cms_request.can_cancel?

    cms_request_id = cms_request.id

    delete(url_for(controller: '/cms_requests', action: :destroy, website_id: cms_request.website.id, id: cms_request.id,
                   format: :xml), accesskey: cms_request.website.accesskey)
    assert_response :success

    xml = get_xml_tree(@response.body)
    assert_element_attribute(-1.to_s, xml.root.elements['status'], 'err_code')
    assert_element_text('Cannot delete: status does not permit to cancel', xml.root.elements['status'])

    reloaded = CmsRequest.where('id=?', cms_request_id).first
    assert reloaded

    # create a request and delete as the user
    cms_request = create_cms_request_plain(client, fnames, orig_language, translation_languages, website, 'page', nil)
    cms_request.update_attributes(status: CMS_REQUEST_RELEASED_TO_TRANSLATORS, pending_tas: 0)

    assert cms_request

    cms_request_id = cms_request.id

    session = login(client)

    assert_equal true, cms_request.can_cancel?

    # delete as a normal user would do
    post(url_for(controller: '/cms_requests', action: :cancel_translation, website_id: cms_request.website.id,
                 id: cms_request.id, format: :xml))
    assert_response :success

    xml = get_xml_tree(@response.body)
    assert_element_attribute('Deleted', xml.root.elements['result'], 'message')

    reloaded = CmsRequest.where('id=?', cms_request_id).first
    assert_nil reloaded

    logout(session)

  end

  def test_send_duplicate_requests
    client = users(:amir)
    website = websites(:amir_drupal_rpc)

    fnames = ['sample/support_files/styles.css.gz']

    orig_language = languages(:English)
    translation_languages = [languages(:Spanish)]

    key = 'that unique string'

    # create a request and delete with as the remote server
    cms_request1 = create_cms_request_plain(client, fnames, orig_language, translation_languages, website, 'page', nil, key, false)
    assert cms_request1

    cms_request2 = create_cms_request_plain(client, fnames, orig_language, translation_languages, website, 'page', nil, key, true)
    assert cms_request2

    assert_equal cms_request1, cms_request2

    cms_request3 = create_cms_request_plain(client, fnames, orig_language, translation_languages, website, 'page', nil, key + 'x', false)
    assert cms_request3

    assert_not_equal cms_request1, cms_request3

  end

  def test_show_correct_languages
    client = users(:amir)
    translator = users(:orit)
    website = websites(:amir_wp)

    fnames = ['sample/support_files/styles.css.gz']

    client_account = client.find_or_create_account(DEFAULT_CURRENCY_ID)
    client_account.update_attributes(balance: 1000)

    orig_language = languages(:English)
    translation_languages = [languages(:Spanish)]

    # create a request and delete with as the remote server
    cms_request = create_cms_request_plain(client, fnames, orig_language, translation_languages, website, 'page', nil)
    cms_request.update_attributes(status: CMS_REQUEST_RELEASED_TO_TRANSLATORS, pending_tas: 0)

    assert cms_request

    # session = login(translator)

    # get(url_for(:controller=>:cms_requests, :action=>:show, :website_id=>website.id, :id=>cms_request.id))
    # assert_response :success

    # open_cms_target_languages = assigns(:open_cms_target_languages)
    # assert open_cms_target_languages
    # assert_equal translation_languages.length-1,open_cms_target_languages.length

  end

  def test_out_of_order_translations
    CmsRequest.destroy_all
    ManagedWork.delete_all
    PendingMoneyTransaction.delete_all

    client = users(:amir)
    translator = users(:orit)
    website = websites(:amir_wp)

    init_email_deliveries

    client_account = client.find_or_create_account(DEFAULT_CURRENCY_ID)
    client_account.update_attributes(balance: 1000)

    # ---- 1) Create several cms request for translation
    fnames = ['sample/support_files/styles.css.gz']

    orig_language = languages(:English)
    translation_languages = [languages(:Spanish)]

    created_cms_requests = []
    [1, 5, 2, 4, 3, 6, 7].each do |idx|
      cms_request, project, revision, ts = create_cms_request(client, fnames, orig_language, translation_languages, website, 'post', idx)
      created_cms_requests << cms_request

      # Create a PendingMoneyTransaction for the CmsRequest
      amount, = cms_request.calculate_required_balance
      PendingMoneyTransaction.reserve_money_for_cms_requests([cms_request])
    end

    assigned_cms_requests = []
    remaining_jobs = 7

    # --- log in as translator and see that we can get this project
    session = login(translator)

    # get the first project
    cms_request = assign_me_next_cms_request(translator, website, remaining_jobs, false, true)
    assert created_cms_requests.include?(cms_request)
    assigned_cms_requests << cms_request
    remaining_jobs -= 1

    # the translator is allowed to pull 3 jobs. We'll pull two more

    # check that the translator can get the next job
    assign_me_next_cms_request(translator, website, remaining_jobs, false, true)
    remaining_jobs -= 1
    # check that the translator can get the next job
    assign_me_next_cms_request(translator, website, remaining_jobs, false, true)
    remaining_jobs -= 1
    # check that the translator can get the next job
    assign_me_next_cms_request(translator, website, remaining_jobs, false, true)
    remaining_jobs -= 1
    # check that the translator can get the next job
    assign_me_next_cms_request(translator, website, remaining_jobs, false, true)
    remaining_jobs -= 1

    # check that the translator cannot get the next project before finishing the current one
    assign_me_next_cms_request(translator, website, remaining_jobs, false, false)

    # force getting a new project (not valid for production)
    for job in 1..2
      cms_request = assign_me_next_cms_request(translator, website, remaining_jobs, true, true)
      assert created_cms_requests.include?(cms_request)
      assert !assigned_cms_requests.include?(cms_request)
      assigned_cms_requests << cms_request
      remaining_jobs -= 1
    end

    logout(session)

    files_to_delete = []

    # the first cms_request has the first ID. A notification should be sent
    upload_completed_translation('proj2_complete', translator, created_cms_requests[0].revision, files_to_delete, 1)

    # these cms_requests have another one before them. A notification should not be sent
    [1, 3].each do |idx|
      upload_completed_translation('proj2_complete', translator, created_cms_requests[idx].revision, files_to_delete, 0)
    end

    upload_completed_translation('proj2_complete', translator, created_cms_requests[2].revision, files_to_delete, 1)
    upload_completed_translation('proj2_complete', translator, created_cms_requests[4].revision, files_to_delete, 3)
    upload_completed_translation('proj2_complete', translator, created_cms_requests[5].revision, files_to_delete, 1)
    upload_completed_translation('proj2_complete', translator, created_cms_requests[6].revision, files_to_delete, 1)

    created_cms_requests.each do |cms|
      cms.reload
      assert_equal 1, cms.delivered

      assert_equal CMS_TARGET_LANGUAGE_TRANSLATED, cms.cms_target_language.status
    end

    files_to_delete.each do |file_to_delete|
      begin
        File.delete(file_to_delete)
      rescue
      end
    end

  end

  def xtest_send_to_different_translators
    CmsRequest.destroy_all
    ManagedWork.delete_all
    PendingMoneyTransaction.delete_all

    files_to_delete = []

    client = users(:amir)
    translator1 = users(:orit)    # will translate to Spanish
    translator2 = users(:newbi)   # will translate to German
    translator3 = users(:stranger) # can translate, but will not translate

    website = websites(:amir_wp)

    spanish = languages(:Spanish)
    german = languages(:German)

    init_email_deliveries
    puts("sending job to translator: #{translator1.email}")
    chat1 = run_send_request(client, translator1, website, 1000, false, [spanish])
    revision = chat1.revision
    project = revision.project

    cms_request = revision.cms_request
    assert_equal CMS_REQUEST_RELEASED_TO_TRANSLATORS, cms_request.status

    # --- translator returns the completed translation

    # since the translator selected himself, there's no reason to send an email notification
    check_emails_delivered(0)

    validate_chat(chat1, website)

    # check that the project was assigned OK to the translator
    check_after_translator_assignment(client, translator1, website, revision, [spanish])

    # create a new version, all texts are completed
    # ---------------- upload support files and a new version ------------------------
    # create a project file that includes the correct support file ID
    upload_completed_translation('proj2_complete', translator1, revision, files_to_delete, 1, [spanish])

    cms_request.reload
    assert_equal CMS_REQUEST_TRANSLATED, cms_request.status

    # log in as 3rd translator and check that there is available work
    session = login(translator3)
    get(url_for(controller: '/translator', action: :open_work))
    assert_response :success

    get(url_for(controller: '/translator', action: :open_work))
    assert_response :success

    open_website_translation_work = assigns(:open_website_translation_work)
    assert_equal 1, open_website_translation_work.length
    logout(session)

    puts("sending job to translator: #{translator2.email}")
    # translator2 does German
    chat2 = run_send_request(client, translator2, website, 1000, true, [german])
    assert_equal revision, chat2.revision

    # --- translator returns the completed translation

    # since the translator selected himself, there's no reason to send an email notification
    check_emails_delivered(0)

    validate_chat(chat2, website)

    # check that the project was assigned OK to the translator
    check_after_translator_assignment(client, translator2, website, revision, [german])

    # create a new version, all texts are completed
    # ---------------- upload support files and a new version ------------------------
    # create a project file that includes the correct support file ID
    upload_completed_translation('proj2_complete_de', translator2, revision, files_to_delete, 1, [german])

    # make sure the target languages have been assigned
    assert_equal CMS_TARGET_LANGUAGE_TRANSLATED, cms.cms_request.cms_target_language.status

    # log in as 3rd translator and check that there's no available work
    session = login(translator3)
    get(url_for(controller: '/translator', action: :open_work))
    assert_response :success

    get(url_for(controller: '/translator', action: :open_work))
    assert_response :success

    open_website_translation_work = assigns(:open_website_translation_work)
    assert_equal 0, open_website_translation_work.length
    logout(session)

    # clean up
    files_to_delete.each { |file_to_delete| File.delete(file_to_delete) }

  end

  def validate_chat(chat, website)
    chat.bids.each do |bid|
      assert_equal BID_ACCEPTED, bid.status
      assert_equal 1, bid.won
      contract = website.website_translation_contracts.joins(:website_translation_offer).where('(website_translation_offers.from_language_id=?) AND
                                                                                                 (website_translation_offers.to_language_id=?) AND
                                                                                                 (website_translation_contracts.status=?)',
                                                                                               revision.language_id, bid.revision_language.language_id, TRANSLATION_CONTRACT_ACCEPTED).first
      assert contract
      assert_equal contract.amount, bid.amount
      assert_equal contract.currency, bid.currency

      # check that the bid has an account with the right sum
      assert bid.account
      expected_amount = contract.amount * chat.revision.lang_word_count(bid.revision_language.language)
      assert expected_amount > 0
      assert_same_amount(expected_amount, bid.account.balance)
    end
  end

  def assign_me_next_cms_request(translator, website, remaining_jobs, force_assign, should_pass)
    get(url_for(controller: :translator))
    assert_response :success
    prev_chats = assigns(:chats).length

    get(url_for(controller: '/translator', action: :open_work))
    assert_response :success

    open_website_translation_work = assigns(:open_website_translation_work)
    if remaining_jobs > 0
      assert_not_equal 0, open_website_translation_work.length
    else
      assert_equal 0, open_website_translation_work.length
    end

    cms_request = open_website_translation_work[0][0]
    revision = cms_request.revision
    assert revision

    # look at the details of the cms_request
    get(url_for(controller: '/cms_requests', action: :show, website_id: website.id, id: cms_request.id))
    assert_response :success

    open_cms_target_languages = assigns(:open_cms_target_languages)
    assert open_cms_target_languages
    assert_equal cms_request.cms_target_languages.length, open_cms_target_languages.length

    args = {}
    open_cms_target_languages.each { |ol| args["cms_target_language[#{ol.id}]"] = 1 }

    # ask to assign all languages
    args['assign_multiple'] = 1 if force_assign

    # puts "requesting to assing cms_request.#{cms_request.id}"
    post url_for(controller: '/cms_requests', action: :assign_to_me, website_id: website.id, id: cms_request.id),
         params: args
    revision.reload

    if should_pass
      assert_response :success
      # check that the revision langauges were created
      assert_equal open_cms_target_languages.length, revision.revision_languages.length
      assert_equal 1, revision.chats.length
      chat = revision.chats[0]
      assert_equal translator, chat.translator
      assert_equal open_cms_target_languages.length, chat.bids.length
    else
      assert_response :redirect
      assert_equal 0, revision.chats.length
    end

    # see that this chat now appears for the translator
    get(url_for(controller: :translator))
    assert_response :success

    if should_pass
      assert_equal prev_chats + 1, assigns(:chats).length
    else
      assert_equal prev_chats, assigns(:chats).length

    end

    cms_request
  end

  def upload_completed_translation(fname, translator, revision, files_to_delete, expected_TAS_notifications, languages = nil)

    cms_request = revision.cms_request
    previous_requests = cms_request.previous_requests
    if expected_TAS_notifications > 0
      assert_equal 0, previous_requests.length
    else
      assert_not_equal 0, previous_requests.length
    end

    stream = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/with_ignores/#{fname}.xml", 'rb')
    support_file_ids = { 355 => 1 }
    listener = XmlRevisionChanger.new('Hotdog', 'veryfirst', revision.id, support_file_ids)
    parser = REXML::Parsers::StreamParser.new(stream, listener)
    parser.parse
    stream.close

    fullpath = "#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/#{fname}.xml.gz"
    Zlib::GzipWriter.open(fullpath) do |gz|
      gz.write(listener.result)
    end
    files_to_delete << fullpath

    session = login(translator)
    trans_version_id = create_version(session, revision.project.id, revision.id, "sample/Initial/#{fname}.xml.gz", true,
                                      expected_TAS_notifications)
    if expected_TAS_notifications > 0
      cms_request.reload
      assert_equal 1, cms_request.pending_tas
      assert_equal LAST_TAS_COMMAND_OUTPUT, cms_request.last_operation

      cms_request.reload
      ctl = cms_request.cms_target_language
      ctl.reload
      if !languages || languages.include?(ctl.language)
        assert_equal 1, ctl.delivered
        assert_equal CMS_TARGET_LANGUAGE_TRANSLATED, ctl.status
      end
      unless languages
        assert_equal 1, cms_request.delivered
        assert_equal CMS_REQUEST_TRANSLATED, cms_request.status
      end
    end

    chat = revision.chats.where('translator_id=?', translator.id).first
    assert chat
    bid = chat.bids.first
    assert bid

    xml_http_request(:post, url_for(controller: '/chats', action: :declare_done, project_id: chat.revision.project_id,
                                    revision_id: chat.revision_id, id: chat.id),
                     lang_id: bid.revision_language.language_id, bid_id: bid.id)
    assert_response :success

    logout(session)

    # TAS updates the status
    if expected_TAS_notifications > 0
      post(url_for(controller: '/cms_requests', action: :update_status, website_id: cms_request.website.id, id: cms_request.id,
                   format: :xml), accesskey: cms_request.website.accesskey, status: CMS_REQUEST_TRANSLATED)
      assert_response :success
    end
  end

  def run_send_request(client, translator, website, client_balance, skip_create = false, languages_to_translate_to = nil, existing_project = nil,
                       _already_notified = false, check_email_count_on_assign_to_me = true)
    client_account = client.find_or_create_account(DEFAULT_CURRENCY_ID)
    client_account.update_attributes!(balance: client_balance)

    if skip_create
      cms_request = website.cms_requests.first
      revision = cms_request.revision
      project = revision.project
      ts = nil
    else
      get(url_for(controller: '/cms_requests', action: :index, website_id: website.id, format: 'xml', accesskey: website.accesskey))
      assert_response :success
      xml = get_xml_tree(@response.body)
      assert_equal 0, assigns(:cms_requests).length unless existing_project

      fnames = ['sample/support_files/styles.css.gz', 'sample/support_files/images/bluebottom.gif.gz']

      orig_language = languages(:English)
      translation_languages = [languages(:Spanish)]

      cms_request, project, revision, ts = create_cms_request(client, fnames, orig_language, translation_languages, website, nil, nil)
      if existing_project
        revision.project = existing_project
        revision.project_completion_duration = 2
        revision.save!
      end
      assert_equal ts, UserSession.where(long_life: 1).order('id DESC').first
    end

    # Create a PendingMoneyTransaction for the CmsRequests
    if client_balance > 0
      amount, = cms_request.calculate_required_balance
      PendingMoneyTransaction.reserve_money_for_cms_requests([cms_request])
    end

    # now, log in as translator and see that we can get this project
    session = login(translator)

    prev_chats_length = revision.chats.length

    get(url_for(controller: :translator))
    assert_response :success
    prev_chats = assigns(:chats).length

    get(url_for(controller: '/translator', action: :open_work))
    assert_response :success

    open_website_translation_work = assigns(:open_website_translation_work)
    unless existing_project
      if client_balance > 0 || cms_request.pending_money_transaction
        assert_equal 1, open_website_translation_work.length,
                     "Expected one open_website_translation_work, got #{open_website_translation_work.length}"
        assert_equal cms_request, open_website_translation_work[0][0]

        # check translator notifications
        # debug_print('before periodic checker')
        checker = PeriodicChecker.new(Time.now)
        cnt = checker.per_profile_mailer
        check_emails_delivered(cnt)

        # next time, translators are no longer notified about these requests
        cnt = checker.per_profile_mailer
        assert_equal 0, cnt
      else
        assert_equal 0, open_website_translation_work.length
      end
    end

    # look at the details of the cms_request
    get(url_for(controller: '/cms_requests', action: :show, website_id: website.id, id: cms_request.id))
    assert_response :success

    open_cms_target_languages = [] # make sure it's a public variable
    if client_balance != 0
      if languages_to_translate_to
        available_open_cms_target_languages = assigns(:open_cms_target_languages)
        open_cms_target_languages = []
        # make sure we're only requesting to translate an available language
        languages_to_translate_to.each do |tl|
          found = false
          available_open_cms_target_languages.each do |aol|
            next unless aol.language == tl
            open_cms_target_languages << aol
            found = true
            break
          end
          assert found, "Cannot find language #{tl.name} in #{(available_open_cms_target_languages.collect { |aol| aol.language.name }).join(',')}"
        end
      else
        open_cms_target_languages = assigns(:open_cms_target_languages)
        assert open_cms_target_languages
        assert_equal 1, open_cms_target_languages.length
      end
    end

    target_languages = {}
    cms_target_languages = []
    open_cms_target_languages.each do |ol|
      target_languages["cms_target_language[#{ol.id}]"] = 1

      cms_target_language = CmsTargetLanguage.find(ol.id)
      assert cms_target_language
      cms_target_languages << cms_target_language
    end

    # ask to assign the requested languages
    delivered_email_count_before = ActionMailer::Base.deliveries.length
    post url_for(controller: '/cms_requests', action: :assign_to_me, website_id: website.id, id: cms_request.id),
         params: target_languages
    assert_equal(ActionMailer::Base.deliveries.length, delivered_email_count_before) if check_email_count_on_assign_to_me

    if client_balance == 0
      assert_response :redirect

      assert_equal prev_chats_length, revision.chats.length
      chat = nil
    else
      assert_response :success

      # check that the revision langauges were created
      revision.reload
      if !languages_to_translate_to
        assert_equal open_cms_target_languages.length, revision.revision_languages.length
      else
        assert open_cms_target_languages.length <= revision.revision_languages.length
      end

      assert_equal prev_chats_length + 1, revision.chats.length
      chat = revision.chats[-1]
      assert_equal translator, chat.translator
      assert_equal open_cms_target_languages.length, chat.bids.length

      # see that this chat now appears for the translator
      get(url_for(controller: :translator))
      assert_response :success

      assert_equal prev_chats + 1, assigns(:chats).length

    end

    if ts && !existing_project
      assert_equal ts, UserSession.where('long_life=?', 1).first
    end

    logout(session)

    if ts && !existing_project
      assert_equal ts, UserSession.where('long_life=?', 1).first
    end

    # make sure that the TAS session doesn't expire
    checker = PeriodicChecker.new(Time.now + (SESSION_TIMEOUT + 1))
    checker.clean_old_sessions

    # This assertion passes on Jenkins but not locally, preventing the test
    # suite from being executed on the developer's machine. Additionally,
    # PeriodicChecker#clean_old_sessions is supposed to clean sessions older
    # than SESSION_TIMEOUT or TAS_TIMEOUT (which are bot set to 1 day), so I
    # don't see how expecting 0 sessions here makes sense given that the test
    # has created new sessions only a few seconds ago.
    # assert_equal 0, UserSession.count

    # TODO: clarify what we need here
    # commented out as long live and normal session timeout the same
    # ts = UserSession.find_by(ts.id) if ts

    # if ts && !existing_project
    #   assert_equal 1, UserSession.count
    #   assert_equal ts, UserSession.first
    # end

    chat
  end

  def create_cms_request(client, fnames, orig_language, translation_languages, website, list_type, list_id,
                         abort_tas = false, key = nil, translator = nil)
    RevisionLanguage.delete_all

    fdata_args = {}
    idx = 1
    fnames.each do |fname|
      fdata_args["file#{idx}"] = { 'uploaded_data' => fixture_file_upload(fname, 'application/octet-stream') }
      idx += 1
    end
    fdata_args['doc_count'] = fnames.length

    idx = 1
    translation_languages.each do |tl|
      fdata_args["to_language#{idx}"] = tl.name
      idx += 1
    end

    if list_type && list_id
      fdata_args['list_type'] = list_type
      fdata_args['list_id'] = list_id
    end

    metas = { 'urgency' => 'low', 'project' => 'hero', 'cost' => 90.3 }
    idx = 1
    metas.each do |name, value|
      fdata_args["meta_name#{idx}"] = name
      fdata_args["meta_value#{idx}"] = value
      idx += 1
    end

    fdata_args['translator_id'] = translator.id if translator

    title = 'Orig title'
    permlink = 'link1-en'
    note = 'This is what I am asking'

    # Create CMS Request
    multipart_post url_for(controller: '/cms_requests', action: :create, website_id: website.id, format: 'xml'),
                   {
                     accesskey: website.accesskey,
                     orig_language: orig_language.name,
                     title: title, permlink: permlink, tas_url: 'dummy_url', tas_port: 12, note: note, key: key
                   }.merge(fdata_args)
    assert_response :success
    xml = get_xml_tree(@response.body)

    assert assigns(:tas_request_notification_sent)
    tas_session = assigns(:tas_session)
    assert tas_session

    ts = UserSession.where('session_num=?', tas_session).first
    assert ts
    assert_equal 1, ts.long_life

    assert_element_attribute('Upload created', xml.root.elements['result'], 'message')
    cms_request_id = get_element_attribute(xml.root.elements['result'], 'id').to_i

    cms_request = CmsRequest.find(cms_request_id)
    assert cms_request
    assert_equal CMS_REQUEST_WAITING_FOR_PROJECT_CREATION, cms_request.status
    assert_equal fnames.length, cms_request.cms_uploads.length
    assert_equal title, cms_request.title
    assert_equal permlink, cms_request.permlink
    assert_equal 'dummy_url', cms_request.tas_url
    assert_equal 12, cms_request.tas_port
    assert_equal 1, cms_request.pending_tas
    assert_equal LAST_TAS_COMMAND_CREATE, cms_request.last_operation
    assert_equal note, cms_request.note

    assert_equal metas.length, cms_request.cms_request_metas.length
    idx = 0
    cms_request.cms_request_metas.each do |cms_request_meta|
      meta_value = metas[cms_request_meta.name]
      assert meta_value
      assert_equal meta_value.to_s, cms_request_meta.value
    end

    assert_equal translation_languages.length, cms_request.cms_target_languages.length
    assert_equal CMS_TARGET_LANGUAGE_CREATED, cms_request.cms_target_language.status

    # this simulates the case where TAS didn't complete processing the request
    return cms_request if abort_tas

    # check that TAS can see these CMS requests
    get(url_for(controller: '/cms_requests', action: :index, website_id: website.id, format: 'xml', accesskey: website.accesskey))
    assert_response :success
    xml = get_xml_tree(@response.body)
    website.reload
    assert_equal website.cms_requests.length, assigns(:cms_requests).length

    # check the cms_request XML report for TAS
    get(url_for(controller: '/cms_requests', action: :show, website_id: website.id, id: cms_request.id, format: 'xml',
                accesskey: website.accesskey))
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute('', xml.root.elements['cms_request'], 'project_id')

    # check that TAS can download all attached documents
    cms_request.cms_uploads.each do |cms_upload|
      get(url_for(controller: '/cms_requests', action: :cms_upload, website_id: website.id, id: cms_request.id,
                  cms_upload_id: cms_upload.id, accesskey: website.accesskey))
      assert_response :success
    end

    # test report errors
    post url_for(controller: '/cms_requests', action: :report_error, website_id: website.id, id: cms_request.id, format: 'xml'),
         params: { accesskey: website.accesskey, error_report: 'This is a serious error' }
    assert_response :success

    cms_request.reload
    assert_equal 'This is a serious error', cms_request.error_description

    # indicate that TAS finished handling
    post url_for(controller: '/cms_requests', action: :notify_tas_done, website_id: website.id, id: cms_request.id, format: 'xml'),
         params: { accesskey: website.accesskey }
    assert_response :success

    cms_request.reload
    assert_equal 0, cms_request.pending_tas

    # logout(session)

    # TAS creates the project, with minimal settings (no language selection)
    project = setup_full_project(client, "cms project instance-#{cms_request.id}", cms_request)
    revision = project.revisions[-1]

    assert_equal cms_request, revision.cms_request

    assert_equal 0, revision.revision_languages.length

    english = languages(:English)
    assert_equal english, revision.language

    # session = login(client)

    # before release, the word count should be left uninitialized
    #   Disabled: On Version#update_statistics called by VersionCont#create we are updating
    #     cms_target_language.word_count because when we update stats from console, the wordcount
    #     was not being updated. - Arnold. Oct 5 2016
    # cms_request.cms_target_languages.each do |cms_target_language|
    # assert_nil cms_target_language.word_count
    # end

    # TAS notifies that the project setup is complete
    post url_for(controller: '/cms_requests', action: :release, website_id: website.id, id: cms_request.id, format: 'xml'),
         params: { accesskey: website.accesskey }
    assert_response :success

    cms_request.reload

    total_cost = 0

    cms_target_language = cms_request.cms_target_language
    assert cms_target_language.word_count
    assert cms_target_language.word_count > 0

    contract =
      website.
      website_translation_contracts.
      includes(:website_translation_offer).
      where(
        '(website_translation_offers.from_language_id=?)
      AND (website_translation_offers.to_language_id = ?)
      AND(website_translation_contracts.status=?)',
        cms_request.language_id,
        cms_target_language.language_id,
        TRANSLATION_CONTRACT_ACCEPTED
      ).first

    if contract
      cost = cms_target_language.word_count * contract.amount
      total_cost += cost
    end

    assert_equal CMS_REQUEST_RELEASED_TO_TRANSLATORS, cms_request.status

    [cms_request, project, revision, ts]
  end

  def check_after_translator_assignment(client, translator, website, revision, languages = nil)
    # check that the request languages are all assigned
    assert revision.cms_request
    cms_request = revision.cms_request
    unless languages
      assert_equal CMS_REQUEST_RELEASED_TO_TRANSLATORS, cms_request.status
    end

    cms_target_language = cms_request.cms_target_language
    if !languages || languages.include?(cms_target_language.language)
      assert_equal CMS_TARGET_LANGUAGE_ASSIGNED, cms_target_language.status
      assert_equal translator, cms_target_language.translator
    end

    # check that the TAS interface shows the project for the cms request
    session = login(client)
    get(url_for(controller: '/cms_requests', action: :show, website_id: website.id, id: cms_request.id, format: 'xml'))
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute(revision.project.id.to_s, xml.root.elements['cms_request'], 'project_id')
    logout(session)
  end

  def create_cms_request_plain(_client, fnames, orig_language, translation_languages, website, list_type, list_id, key = nil, duplicate = false)
    fdata_args = {}
    idx = 1
    fnames.each do |fname|
      fdata_args["file#{idx}"] = { 'uploaded_data' => fixture_file_upload(fname, 'application/octet-stream') }
      idx += 1
    end
    fdata_args['doc_count'] = fnames.length

    idx = 1
    translation_languages.each do |tl|
      fdata_args["to_language#{idx}"] = tl.name
      idx += 1
    end

    if list_type && list_id
      fdata_args['list_type'] = list_type
      fdata_args['list_id'] = list_id
    end

    title = 'Orig title'
    permlink = 'link1-en'
    multipart_post url_for(controller: '/cms_requests', action: :create, website_id: website.id, format: 'xml'),
                   {
                     accesskey: website.accesskey,
                     orig_language: orig_language.name,
                     title: title, permlink: permlink, tas_url: 'dummy_url', tas_port: 12, key: key
                   }.merge(fdata_args)
    assert_response :success
    xml = get_xml_tree(@response.body)

    if !duplicate
      assert assigns(:tas_request_notification_sent)
      tas_session = assigns(:tas_session)
      assert tas_session

      ts = UserSession.where('session_num=?', tas_session).first
      assert ts
      assert_equal 1, ts.long_life

    else
      # our server still notifies the CMS of the completed original job
      assert assigns(:tas_request_notification_sent)
      assert_nil assigns(:tas_session)
    end

    assert_element_attribute('Upload created', xml.root.elements['result'], 'message')
    cms_request_id = get_element_attribute(xml.root.elements['result'], 'id').to_i

    cms_request = CmsRequest.find(cms_request_id)
    assert cms_request

    cms_request
  end

  def test_create_by_cms

    Website.destroy_all
    WebsiteTranslationOffer.destroy_all
    WebsiteTranslationContract.destroy_all
    CmsRequest.destroy_all
    ManagedWork.delete_all
    PendingMoneyTransaction.delete_all

    init_email_deliveries

    # --- make sure that translators still don't see the offers for this client
    translator = users(:orit)
    prev_open_offers = translator.open_website_translation_offers.length

    email = 'someone@sample.com'
    fname = 'rosh'
    lname = 'hashana'
    url = 'http://www.sample.com'
    title = 'the name of the project'
    description = 'what we are going to do in the project'
    platform_kind = WEBSITE_DRUPAL
    pickup_type = PICKUP_BY_RPC_POST
    notifications = WEBSITE_NOTIFY_DELIVERY
    interview_translators = 1

    language_pairs = [[languages(:English), languages(:Spanish)], [languages(:English), languages(:French)]]
    language_names = language_names_args(language_pairs)

    # test with incomplete details (not language information)
    post url_for(controller: '/websites', action: :create_by_cms, format: :xml),
         params: {
           email: email, fname: fname, lname: lname, create_account: 1, url: url, title: title, description: description,
           interview_translators: 1, platform_kind: platform_kind, pickup_type: pickup_type
         }
    assert_response :success

    xml = get_xml_tree(@response.body)
    assert_element_text('1', xml.root.elements['aborted'])

    check_emails_delivered(0)

    # test with incomplete user information

    otheruser = users(:amir)

    [{ fname: fname, lname: lname }, { email: email, lname: lname }, { email: email, fname: fname }, { email: otheruser.email,
                                                                                                       fname: fname,
                                                                                                       lname: lname }].each do |user_details|
      post url_for(controller: '/websites', action: :create_by_cms, format: :xml),
           params: {
             create_account: 1, url: url, title: title, description: description,
             interview_translators: 1, platform_kind: platform_kind, pickup_type: pickup_type
           }.merge(language_names).merge(user_details)
      assert_response :success

      xml = get_xml_tree(@response.body)
      assert_element_text('1', xml.root.elements['aborted'])
    end

    users_count = User.count

    check_emails_delivered(0)
    # complete request
    post url_for(controller: '/websites', action: :create_by_cms, format: :xml),
         params: {
           email: email, fname: fname, lname: lname, create_account: 1, url: url, title: title, description: description,
           interview_translators: interview_translators, platform_kind: platform_kind, pickup_type: pickup_type, notifications: notifications,
           project_kind: PRODUCTION_CMS_WEBSITE,
           cms_kind: CMS_KIND_WORDPRESS, cms_description: 'WordPress 2.1',
           word_count: 123, wc_description: 'this is cool'
         }.merge(language_names)
    assert_response :success

    xml = get_xml_tree(@response.body)
    website = assigns(:website)
    assert website
    assert_element_attribute(website.id.to_s, xml.root.elements['website'], 'id')
    assert_element_attribute(website.accesskey.to_s, xml.root.elements['website'], 'accesskey')
    assert_equal website.interview_translators, interview_translators
    assert_equal PRODUCTION_CMS_WEBSITE, website.project_kind
    assert_equal CMS_KIND_WORDPRESS, website.cms_kind
    assert_equal 'WordPress 2.1', website.cms_description
    assert_equal title, website.name
    assert_equal 123, website.word_count
    assert_equal 'this is cool', website.wc_description

    assert_equal notifications, website.notifications

    assert_equal language_pairs.length, website.website_translation_offers.length
    website.website_translation_offers.each { |offer| assert_equal TRANSLATION_OFFER_OPEN, offer.status }

    assert_equal users_count + 1, User.count

    # verify the new client's status
    user = website.client
    assert_equal USER_STATUS_NEW, user.userstatus

    # make sure that the client has a money account with zero balance
    assert_equal 1, user.money_accounts.length
    money_account = user.money_accounts[0]
    assert_equal 0, money_account.balance
    assert_equal DEFAULT_CURRENCY_ID, money_account.currency.id

    assert_equal nil, user.loc_code

    # as if the user clicked on the account setup link
    user.update_attributes(userstatus: USER_STATUS_REGISTERED)

    # --- until clients send jobs to translation, translators don't see the new project
    assert_equal prev_open_offers, translator.open_website_translation_offers.length

    # display that page from the CMS
    get(url_for(controller: '/wpml/websites', action: :show, id: website.id, accesskey: website.accesskey, lc: 'es'))
    assert_response :success

    user.reload
    assert_equal 'es_ES', user.loc_code

    # create a CMS request, so that the translator can see the project
    fnames = ['sample/support_files/styles.css.gz', 'sample/support_files/images/bluebottom.gif.gz']

    orig_language = languages(:English)
    translation_languages = [languages(:Spanish)]
    cms_request, project, revision, ts = create_cms_request(user, fnames, orig_language, translation_languages, website, nil, nil)

    # HACK
    website.website_translation_offers.each { |offer| offer.update_attributes(invitation: 'something') }

    # --- until clients send jobs to translation, translators don't see the new project
    assert_equal prev_open_offers + language_pairs.length, translator.open_website_translation_offers.length

    # --- log in as a translator and apply to these offers
    translator = users(:orit)
    session = login(translator)

    get(url_for(controller: '/translator', action: :open_work))
    assert_response :success

    open_website_translation_offers = assigns(:open_website_translation_offers)
    assert open_website_translation_offers
    assert_equal 2, open_website_translation_offers.length

    open_website_translation_offers.each do |offer|
      assert_equal website, offer.website

      get(url_for(controller: '/website_translation_contracts', action: :new, website_id: offer.website.id,
                  website_translation_offer_id: offer.id))
      assert_response :success

      post(url_for(controller: '/website_translation_contracts', action: :create, website_id: offer.website.id,
                   website_translation_offer_id: offer.id),
           message: 'I want to try')
      assert_response :success
      offer.reload
      assert_equal 0, offer.website_translation_contracts.length

      post(url_for(controller: '/website_translation_contracts', action: :create, website_id: offer.website.id,
                   website_translation_offer_id: offer.id),
           apply: 1)
      assert_response :success
      offer.reload
      assert_equal 0, offer.website_translation_contracts.length

      post(url_for(controller: '/website_translation_contracts', action: :create, website_id: offer.website.id,
                   website_translation_offer_id: offer.id),
           apply: 1, message: 'I want to try')
      assert_response :success
      offer.reload
      assert_equal 0, offer.website_translation_contracts.length

      post(url_for(controller: '/website_translation_contracts', action: :create, website_id: offer.website.id,
                   website_translation_offer_id: offer.id),
           apply: 1, message: 'I want to try', website_translation_contract: { amount: 0.09 })
      assert_response :redirect

      offer.reload
      assert_equal 1, offer.website_translation_contracts.length

      check_emails_delivered(1)

      offer.website_translation_contracts.each do |c|
        assert_equal TRANSLATION_CONTRACT_REQUESTED, c.status
        assert_equal translator, c.translator

        num_messages = c.messages.length

        post(url_for(controller: '/website_translation_contracts', action: :create_message, id: c.id, website_id: offer.website.id,
                     website_translation_offer_id: offer.id, format: :js),
             body: 'You should also see the accesskey', max_idx: 1, for_who1: website.client.id)
        # assert_response :redirect

        check_emails_delivered(1)

        c.reload
        assert_equal num_messages + 1, c.messages.length
      end
    end

    assert_equal 4, website.reminders.length # 2 new applications and 2 new messages

    logout(session)

    # now the user can log in
    check_website_pages(website, user, true)

    # create another project for this user
    title = 'another CMS project'

    # password problems
    [nil, get_user_test_password(user) + 'x'].each do |password|
      post url_for(controller: '/websites', action: :create_by_cms, format: :xml),
           params: {
             email: email, password: password, create_account: 0, url: url, title: title, description: description,
             interview_translators: 1, platform_kind: platform_kind, pickup_type: pickup_type
           }.merge(language_names)
      assert_response :success

      xml = get_xml_tree(@response.body)
      assert_element_text('1', xml.root.elements['aborted'])
    end

    # correct password
    post url_for(controller: '/websites', action: :create_by_cms, format: :xml),
         params: {
           email: email, password: get_user_test_password(user), create_account: 0, url: url, title: title, description: description,
           interview_translators: 1, platform_kind: platform_kind, pickup_type: pickup_type
         }.merge(language_names)
    assert_response :success

    xml = get_xml_tree(@response.body)
    # puts xml

    website = assigns(:website)
    assert website
    assert_element_attribute(website.id.to_s, xml.root.elements['website'], 'id')
    assert_element_attribute(website.accesskey.to_s, xml.root.elements['website'], 'accesskey')

    assert_equal language_pairs.length, website.website_translation_offers.length

    check_emails_delivered(0)

    # make sure that the user is still registered
    user = website.client
    assert_equal USER_STATUS_REGISTERED, user.userstatus

    check_website_pages(website, user, true)

    # --- update that website with new parameters ---
    # 1. without an accesskey
    post(url_for(controller: '/websites', action: :update_by_cms, id: website.id, format: :xml))
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_text('1', xml.root.elements['aborted'])

    # 2. a blank request shouldn't change anything
    post url_for(controller: '/websites', action: :update_by_cms, id: website.id, format: :xml),
         params: { accesskey: website.accesskey }
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute(website.id.to_s, xml.root.elements['website'], 'id')

    # 3. update some parameters
    post url_for(controller: '/websites', action: :update_by_cms, id: website.id, format: :xml),
         params: {
           accesskey: website.accesskey, title: title + 'X', description: description + 'Y',
           pickup_type: 1 - pickup_type, notifications: notifications + 1,
           word_count: 234, wc_description: 'this is very cool'
         }
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute(website.id.to_s, xml.root.elements['website'], 'id')

    website.reload
    assert_equal website.name, title + 'X'
    assert_equal website.description, description + 'Y'
    assert_equal website.pickup_type, 1 - pickup_type
    assert_equal website.notifications, notifications + 1
    assert_equal 234, website.word_count
    assert_equal 'this is very cool', website.wc_description

    # 4. add languages
    language_pairs = [[languages(:English), languages(:Spanish)], [languages(:English), languages(:French)], [languages(:Spanish),
                                                                                                              languages(:German)]]
    new_language_names = language_names_args(language_pairs)

    post url_for(controller: '/websites', action: :update_by_cms, id: website.id, format: :xml),
         params: { accesskey: website.accesskey }.merge(new_language_names).merge(language_names)
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute(website.id.to_s, xml.root.elements['website'], 'id')

    website.reload
    assert_equal language_pairs.length, website.website_translation_offers.length

    # 5. drop languages
    language_pairs = [[languages(:English), languages(:French)], [languages(:Spanish), languages(:German)]]
    new_language_names = language_names_args(language_pairs)

    post url_for(controller: '/websites', action: :update_by_cms, id: website.id, format: :xml),
         params: { accesskey: website.accesskey }.merge(new_language_names).merge(language_names)
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute(website.id.to_s, xml.root.elements['website'], 'id')

    website.reload
    assert_equal language_pairs.length + 1, website.website_translation_offers.length # the dropped pair is still there

    # suspended_offers = website.website_translation_offers.where('status=?',TRANSLATION_OFFER_SUSPENDED)
    # assert_equal 1,suspended_offers.length

    # 6. add back the languages
    language_pairs = [[languages(:English), languages(:Spanish)], [languages(:English), languages(:French)], [languages(:Spanish),
                                                                                                              languages(:German)]]
    new_language_names = language_names_args(language_pairs)

    post url_for(controller: '/websites', action: :update_by_cms, id: website.id, format: :xml),
         params: { accesskey: website.accesskey }.merge(new_language_names).merge(language_names)
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute(website.id.to_s, xml.root.elements['website'], 'id')

    website.reload
    assert_equal language_pairs.length, website.website_translation_offers.length

    suspended_offers = website.website_translation_offers.where('status=?', TRANSLATION_OFFER_SUSPENDED)
    assert_equal 0, suspended_offers.length

    check_website_pages(website, user, true)
  end

  def test_create_with_blank_title
    Website.destroy_all
    WebsiteTranslationOffer.destroy_all
    WebsiteTranslationContract.destroy_all
    CmsRequest.destroy_all
    ManagedWork.delete_all
    PendingMoneyTransaction.delete_all

    init_email_deliveries

    email = 'someone@sample.com'
    fname = 'rosh'
    lname = 'hashana'
    url = 'http://www.blank-title.com'
    title = ''
    description = 'what we are going to do in the project'
    platform_kind = WEBSITE_DRUPAL
    pickup_type = PICKUP_BY_RPC_POST
    notifications = WEBSITE_NOTIFY_DELIVERY
    interview_translators = 1

    language_pairs = [[languages(:English), languages(:Spanish)], [languages(:English), languages(:French)]]
    language_names = language_names_args(language_pairs)

    # complete request
    post url_for(controller: '/websites', action: :create_by_cms, format: :xml),
         params: {
           email: email, fname: fname, lname: lname, create_account: 1, url: url, title: title, description: description,
           interview_translators: interview_translators, platform_kind: platform_kind, pickup_type: pickup_type, notifications: notifications,
           project_kind: PRODUCTION_CMS_WEBSITE,
           cms_kind: CMS_KIND_WORDPRESS, cms_description: 'WordPress 2.1'
         }.merge(language_names)
    assert_response :success

    xml = get_xml_tree(@response.body)

    website = assigns(:website)
    assert website
    assert_element_attribute(website.id.to_s, xml.root.elements['website'], 'id')
    assert_element_attribute(website.accesskey.to_s, xml.root.elements['website'], 'accesskey')
    assert_equal website.interview_translators, interview_translators
    assert_equal PRODUCTION_CMS_WEBSITE, website.project_kind
    assert_equal CMS_KIND_WORDPRESS, website.cms_kind
    assert_equal 'WordPress 2.1', website.cms_description
    assert_equal 'www.blank-title.com', website.name

  end

  def test_create_verified_by_cms

    Website.destroy_all
    WebsiteTranslationOffer.destroy_all
    WebsiteTranslationContract.destroy_all
    CmsRequest.destroy_all
    ManagedWork.delete_all
    PendingMoneyTransaction.delete_all

    users_count = User.count

    init_email_deliveries

    email = 'someone@sample.com'
    fname = 'rosh'
    lname = 'hashana'
    url = 'http://www.sample.com'
    title = 'the name of the project'
    description = 'what we are going to do in the project'
    platform_kind = WEBSITE_DRUPAL
    pickup_type = PICKUP_BY_RPC_POST
    notifications = WEBSITE_NOTIFY_DELIVERY
    interview_translators = 0

    language_pairs = [[languages(:English), languages(:Spanish)], [languages(:English), languages(:French)]]
    language_names = language_names_args(language_pairs)

    # complete request
    post url_for(controller: '/websites', action: :create_by_cms, format: :xml),
         params: {
           email: email, fname: fname, lname: lname, create_account: 1, url: url, title: title, description: description,
           interview_translators: interview_translators, platform_kind: platform_kind, pickup_type: pickup_type, notifications: notifications,
           project_kind: PRODUCTION_CMS_WEBSITE,
           cms_kind: CMS_KIND_WORDPRESS, cms_description: 'WordPress 2.1', is_verified: 1
         }.merge(language_names)
    assert_response :success

    xml = get_xml_tree(@response.body)

    website = assigns(:website)
    assert website
    assert_element_attribute(website.id.to_s, xml.root.elements['website'], 'id')
    assert_element_attribute(website.accesskey.to_s, xml.root.elements['website'], 'accesskey')
    assert_equal website.interview_translators, interview_translators
    assert_equal PRODUCTION_CMS_WEBSITE, website.project_kind
    assert_equal CMS_KIND_WORDPRESS, website.cms_kind
    assert_equal 'WordPress 2.1', website.cms_description
    assert_equal 1, website.free_support

    assert_equal notifications, website.notifications

    assert_equal language_pairs.length, website.website_translation_offers.length
    website.website_translation_offers.each { |offer| assert_equal TRANSLATION_OFFER_OPEN, offer.status }

    assert_equal users_count + 1, User.count

    # verify the new client's status
    user = website.client
    assert_equal USER_STATUS_REGISTERED, user.userstatus
  end

  def test_create_create_anon

    Website.destroy_all
    WebsiteTranslationOffer.destroy_all
    WebsiteTranslationContract.destroy_all
    CmsRequest.destroy_all
    ManagedWork.delete_all
    PendingMoneyTransaction.delete_all

    users_count = User.count

    init_email_deliveries

    affiliate = users(:amir)

    url = 'http://www.sample.com'
    title = 'the name of the project'
    description = 'what we are going to do in the project'
    platform_kind = WEBSITE_DRUPAL
    pickup_type = PICKUP_BY_RPC_POST
    notifications = WEBSITE_NOTIFY_DELIVERY
    interview_translators = 0

    language_pairs = [[languages(:English), languages(:Spanish)], [languages(:English), languages(:French)]]
    language_names = language_names_args(language_pairs)

    # complete request
    post url_for(controller: '/websites', action: :create_by_cms, format: :xml),
         params: {
           create_account: 1, anon: 1, url: url, title: title, description: description,
           interview_translators: interview_translators, platform_kind: platform_kind, pickup_type: pickup_type, notifications: notifications,
           project_kind: PRODUCTION_CMS_WEBSITE,
           cms_kind: CMS_KIND_WORDPRESS, cms_description: 'WordPress 2.1', is_verified: 1, ignore_languages: 1,
           affiliate_id: affiliate.id, affiliate_key: affiliate.affiliate_key
         }
    assert_response :success

    xml = get_xml_tree(@response.body)

    website = assigns(:website)
    assert website
    assert_element_attribute(website.id.to_s, xml.root.elements['website'], 'id')
    assert_element_attribute(website.accesskey.to_s, xml.root.elements['website'], 'accesskey')
    assert_equal website.interview_translators, interview_translators
    assert_equal PRODUCTION_CMS_WEBSITE, website.project_kind
    assert_equal CMS_KIND_WORDPRESS, website.cms_kind
    assert_equal 'WordPress 2.1', website.cms_description
    assert_equal 1, website.free_support
    assert_equal 1, website.anon

    assert_equal notifications, website.notifications

    assert_equal 0, website.website_translation_offers.length

    check_emails_delivered(0) # no one to deliver the email

    assert_equal users_count + 1, User.count

    # verify the new client's status
    user = website.client
    # assert_equal USER_STATUS_REGISTERED, user.userstatus
    assert_equal 1, user.anon

    assert_equal affiliate, user.affiliate

    # add a language
    language_pairs = [[languages(:English), languages(:Spanish)]]
    new_language_names = language_names_args(language_pairs)

    post url_for(controller: '/websites', action: :update_by_cms, id: website.id, format: :xml),
         params: { accesskey: website.accesskey }.merge(new_language_names)
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute(website.id.to_s, xml.root.elements['website'], 'id')

    website.reload
    assert_equal language_pairs.length, website.website_translation_offers.length

    website_translation_offer = website.website_translation_offers[0]

    UserSession.delete_all
    user_session_count = UserSession.count

    assert_equal user_session_count + 0, UserSession.count

    # now, check we can access with the accesskey
    # 1. without an accesskey - error
    get(url_for(controller: '/website_translation_offers', action: :show, website_id: website.id, id: website_translation_offer.id))
    assert_response :redirect

    assert_equal user_session_count + 0, UserSession.count

    # 2. with accesskey - ok
    get(url_for(controller: '/website_translation_offers', action: :show, website_id: website.id, id: website_translation_offer.id, accesskey: website.accesskey, compact: 1))
    assert_response :success

    assert_equal user_session_count + 1, UserSession.count

    user_session = UserSession.all.to_a[-1]
    assert_equal COMPACT_SESSION, user_session.display

    # 3. once logged in, accesskey no longer required
    get(url_for(controller: '/website_translation_offers', action: :show, website_id: website.id, id: website_translation_offer.id))
    assert_response :success

    # no new session
    assert_equal user_session_count + 1, UserSession.count

    assert_equal 0, website_translation_offer.website_translation_contracts.length

    # invite a translator
    translator_contracts = assigns(:translator_contracts)
    translators = assigns(:translators)

    assert translator_contracts
    assert translators
    assert !translators.empty?

    translator = translators[0]

    translator_reminders = translator.reminders.count

    get(url_for(controller: '/website_translation_offers', action: :new_invitation, website_id: website.id,
                id: website_translation_offer.id, translator_id: translator.id))
    assert_response :success

    # no arguments at all, nothing created
    post(url_for(controller: '/website_translation_offers', action: :create_invitation, website_id: website.id,
                 id: website_translation_offer.id, translator_id: translator.id))
    assert_response :success

    website_translation_offer.reload
    assert_equal 0, website_translation_offer.website_translation_contracts.length

    # no user information, still no new contract
    post(url_for(controller: '/website_translation_offers', action: :create_invitation, website_id: website.id,
                 id: website_translation_offer.id, translator_id: translator.id),
         website_translation_offer: { invitation: 'hello there' }, title: 'website title', description: 'about this', create_account: 1)
    assert_response :success

    website_translation_offer.reload
    assert_equal 0, website_translation_offer.website_translation_contracts.length

    check_emails_delivered(0) # up to now, no emails

    assert_equal TRANSLATION_OFFER_CLOSED, website_translation_offer.status
    assert_equal 0, website_translation_offer.sent_notifications.length

    # full info
    post(url_for(controller: '/website_translation_offers', action: :create_invitation, website_id: website.id,
                 id: website_translation_offer.id, translator_id: translator.id),
         website_translation_offer: { invitation: 'hello there' }, title: 'website title', description: 'about this',
         fname: 'jack', lname: 'job', email: 'jack@jobs.com', create_account: 1)
    assert_response :redirect

    website_translation_offer.reload
    assert_equal 1, website_translation_offer.website_translation_contracts.length
    assert_equal 1, website_translation_offer.sent_notifications.length

    assert_equal TRANSLATION_OFFER_CLOSED, website_translation_offer.status # still closed

    contract = website_translation_offer.website_translation_contracts[0]
    assert_equal 1, contract.messages.length

    assert_match(/I would like you to translate my website/, contract.messages[0].body)

    check_emails_delivered(2)

    translator.reload
    assert_equal translator_reminders + 1, translator.reminders.count

    user.reload
    assert_equal 0, user.anon
    assert_equal affiliate, user.affiliate

    assert_equal 'jack@jobs.com', user.email
    assert_equal 'jack', user.fname
    assert_equal 'job', user.lname

    # ---- add a new language and send another message

    # add a language
    language_pairs = [[languages(:English), languages(:Spanish)], [languages(:English), languages(:French)]]
    new_language_names = language_names_args(language_pairs)

    post url_for(controller: '/websites', action: :update_by_cms, id: website.id, format: :xml),
         params: { accesskey: website.accesskey }.merge(new_language_names)
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute(website.id.to_s, xml.root.elements['website'], 'id')

    website.reload
    assert_equal language_pairs.length, website.website_translation_offers.length

    website_translation_offer = website.website_translation_offers[1]

    get(url_for(controller: '/website_translation_offers', action: :show, website_id: website.id, id: website_translation_offer.id,
                accesskey: website.accesskey, compact: 1))
    assert_response :success

    assert_equal 0, website_translation_offer.website_translation_contracts.length

    # invite a translator
    translator_contracts = assigns(:translator_contracts)
    translators = assigns(:translators)

    assert translator_contracts
    assert translators
    assert !translators.empty?

    translator = translators[0]

    post(url_for(controller: '/website_translation_offers', action: :create_invitation, website_id: website.id,
                 id: website_translation_offer.id, translator_id: translator.id))
    assert_response :redirect

    website_translation_offer.reload
    assert_equal 1, website_translation_offer.website_translation_contracts.length

    contract = website_translation_offer.website_translation_contracts[0]
    assert_equal 1, contract.messages.length

    assert_match(/I would like you to translate my website/, contract.messages[0].body)

    check_emails_delivered(1)

    # user is still not anon
    user.reload
    assert_equal 0, user.anon

    website.reload
    assert_equal 0, website.anon

  end

  def test_create_anon_and_login

    Website.destroy_all
    WebsiteTranslationOffer.destroy_all
    WebsiteTranslationContract.destroy_all
    CmsRequest.destroy_all
    ManagedWork.delete_all
    PendingMoneyTransaction.delete_all

    users_count = User.count

    init_email_deliveries

    affiliate = users(:orit)

    existing_client = users(:amir)

    url = 'http://www.sample.com'
    title = 'the name of the project'
    description = 'what we are going to do in the project'
    platform_kind = WEBSITE_DRUPAL
    pickup_type = PICKUP_BY_RPC_POST
    notifications = WEBSITE_NOTIFY_DELIVERY
    interview_translators = 0

    language_pairs = [[languages(:English), languages(:Spanish)], [languages(:English), languages(:French)]]
    language_names = language_names_args(language_pairs)

    # complete request
    post url_for(controller: '/websites', action: :create_by_cms, format: :xml),
         params: {
           create_account: 1, anon: 1, url: url, title: title, description: description,
           interview_translators: interview_translators, platform_kind: platform_kind, pickup_type: pickup_type, notifications: notifications,
           project_kind: PRODUCTION_CMS_WEBSITE,
           cms_kind: CMS_KIND_WORDPRESS, cms_description: 'WordPress 2.1', is_verified: 1, ignore_languages: 1,
           affiliate_id: affiliate.id, affiliate_key: affiliate.affiliate_key
         }
    assert_response :success

    xml = get_xml_tree(@response.body)

    website = assigns(:website)
    assert website
    assert_element_attribute(website.id.to_s, xml.root.elements['website'], 'id')
    assert_element_attribute(website.accesskey.to_s, xml.root.elements['website'], 'accesskey')
    assert_equal website.interview_translators, interview_translators
    assert_equal PRODUCTION_CMS_WEBSITE, website.project_kind
    assert_equal CMS_KIND_WORDPRESS, website.cms_kind
    assert_equal 'WordPress 2.1', website.cms_description
    assert_equal 1, website.free_support

    assert_equal notifications, website.notifications

    assert_equal 0, website.website_translation_offers.length

    check_emails_delivered(0) # no one to deliver the email

    assert_equal users_count + 1, User.count

    # verify the new client's status
    user = website.client
    # assert_equal USER_STATUS_REGISTERED, user.userstatus
    assert_equal 1, user.anon
    assert_equal affiliate, user.affiliate

    # add a language
    language_pairs = [[languages(:English), languages(:Spanish)]]
    new_language_names = language_names_args(language_pairs)

    post url_for(controller: '/websites', action: :update_by_cms, id: website.id, format: :xml),
         params: { accesskey: website.accesskey }.merge(new_language_names)
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute(website.id.to_s, xml.root.elements['website'], 'id')

    website.reload
    assert_equal language_pairs.length, website.website_translation_offers.length

    website_translation_offer = website.website_translation_offers[0]

    UserSession.delete_all
    user_session_count = UserSession.count

    assert_equal user_session_count + 0, UserSession.count

    # 2. with accesskey - ok
    get(url_for(controller: '/website_translation_offers', action: :show, website_id: website.id, id: website_translation_offer.id,
                accesskey: website.accesskey, compact: 1))
    assert_response :success

    assert_equal user_session_count + 1, UserSession.count

    user_session = UserSession.all.to_a[-1]
    assert_equal COMPACT_SESSION, user_session.display

    # no new session
    assert_equal user_session_count + 1, UserSession.count

    assert_equal 0, website_translation_offer.website_translation_contracts.length

    # invite a translator
    translator_contracts = assigns(:translator_contracts)
    translators = assigns(:translators)

    assert translator_contracts
    assert translators
    assert !translators.empty?

    translator = translators[0]

    translator_reminders = translator.reminders.count

    get(url_for(controller: '/website_translation_offers', action: :new_invitation, website_id: website.id,
                id: website_translation_offer.id, translator_id: translator.id))
    assert_response :success

    check_emails_delivered(0) # up to now, no emails

    existing_affiliate_id = existing_client.affiliate_id

    # full info with password to existing account
    post(url_for(controller: '/website_translation_offers', action: :create_invitation, website_id: website.id,
                 id: website_translation_offer.id, translator_id: translator.id),
         title: 'website title', description: 'about this',
         email1: existing_client.email, password: get_user_test_password(existing_client), create_account: 0)
    assert_response :redirect

    website_translation_offer.reload
    website.reload

    assert_equal 1, website_translation_offer.website_translation_contracts.length

    contract = website_translation_offer.website_translation_contracts[0]
    assert_equal 1, contract.messages.length

    assert_match(/I would like you to translate my website/, contract.messages[0].body)

    check_emails_delivered(1) # only one to the translator

    translator.reload
    assert_equal translator_reminders + 1, translator.reminders.count

    assert_equal existing_client, website.client
    assert_not_equal existing_client, user

    user = website.client.reload
    assert user.anon != 1
    assert_equal existing_affiliate_id, user.affiliate_id

    website.reload
    assert_equal 0, website.anon

    # see that we are still logged in
    get(url_for(controller: '/website_translation_offers', action: :show, website_id: website.id, id: website_translation_offer.id))
    assert_response :success

  end

  def test_create_anon_support_and_login

    Website.destroy_all
    WebsiteTranslationOffer.destroy_all
    WebsiteTranslationContract.destroy_all
    CmsRequest.destroy_all
    ManagedWork.delete_all
    PendingMoneyTransaction.delete_all

    users_count = User.count

    init_email_deliveries

    url = 'http://www.sample.com'
    title = 'the name of the project'
    description = 'what we are going to do in the project'
    platform_kind = WEBSITE_DRUPAL
    pickup_type = PICKUP_BY_RPC_POST
    notifications = WEBSITE_NOTIFY_DELIVERY
    interview_translators = 0

    language_pairs = [[languages(:English), languages(:Spanish)], [languages(:English), languages(:French)]]
    language_names = language_names_args(language_pairs)

    # complete request
    post url_for(controller: '/websites', action: :create_by_cms, format: :xml),
         params: {
           create_account: 1, anon: 1, url: url, title: title, description: description,
           interview_translators: interview_translators, platform_kind: platform_kind, pickup_type: pickup_type, notifications: notifications,
           project_kind: PRODUCTION_CMS_WEBSITE,
           cms_kind: CMS_KIND_WORDPRESS, cms_description: 'WordPress 2.1', is_verified: 1, ignore_languages: 1
         }
    assert_response :success

    xml = get_xml_tree(@response.body)

    website = assigns(:website)
    assert website
    assert_element_attribute(website.id.to_s, xml.root.elements['website'], 'id')
    assert_element_attribute(website.accesskey.to_s, xml.root.elements['website'], 'accesskey')
    assert_equal website.interview_translators, interview_translators
    assert_equal PRODUCTION_CMS_WEBSITE, website.project_kind
    assert_equal CMS_KIND_WORDPRESS, website.cms_kind
    assert_equal 'WordPress 2.1', website.cms_description
    assert_equal 1, website.free_support

    assert_equal notifications, website.notifications

    assert_equal 0, website.website_translation_offers.length

    check_emails_delivered(0) # no one to deliver the email

    assert_equal users_count + 1, User.count

    # verify the new client's status
    user = website.client
    # assert_equal USER_STATUS_REGISTERED, user.userstatus
    assert_equal 1, user.anon

    # add a language
    language_pairs = [[languages(:English), languages(:Spanish)]]
    new_language_names = language_names_args(language_pairs)

    post url_for(controller: '/websites', action: :update_by_cms, id: website.id, format: :xml),
         params: { accesskey: website.accesskey }.merge(new_language_names)
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute(website.id.to_s, xml.root.elements['website'], 'id')

    website.reload
    assert_equal language_pairs.length, website.website_translation_offers.length

    website_translation_offer = website.website_translation_offers[0]

    UserSession.delete_all
    user_session_count = UserSession.count

    assert_equal user_session_count + 0, UserSession.count

    # create a support ticket

    get(url_for(controller: '/support', wid: website.id, accesskey: website.accesskey))
    assert_response :success

    assert_equal user_session_count + 1, UserSession.count

    get(url_for(controller: '/support', action: :new))
    assert_response :redirect

    get(url_for(controller: '/users', action: :signup, return_to: url_for(controller: '/support', action: :new)))
    assert_response :success

    # incomplete details
    post url_for(controller: '/users', action: :update_name_and_email),
         params: { lname: 'smith', email: 'js@mail.com', create_account: 1, back: 'back', return_to: 'return' }
    assert_response :success

    check_emails_delivered(0)

    # full details
    post url_for(controller: '/users', action: :update_name_and_email),
         params: { fname: 'jake', lname: 'smith', email: 'js@mail.com', create_account: 1, back: 'back' } # 'return' is not a recognizable path
    assert_response :redirect

    check_emails_delivered(1) # the client gets a welcome email

    user.reload
    assert_equal 0, user.anon

    # 2. with accesskey - ok
    get(url_for(controller: '/website_translation_offers', action: :show, website_id: website.id, id: website_translation_offer.id,
                accesskey: website.accesskey, compact: 1))
    assert_response :success

    assert_equal user_session_count + 2, UserSession.count

    user_session = UserSession.all.to_a[-1]
    assert_equal COMPACT_SESSION, user_session.display

    # no new session
    assert_equal user_session_count + 2, UserSession.count

    assert_equal 0, website_translation_offer.website_translation_contracts.length

    # invite a translator
    translator_contracts = assigns(:translator_contracts)
    translators = assigns(:translators)

    assert translator_contracts
    assert translators
    assert !translators.empty?

    translator = translators[0]

    translator_reminders = translator.reminders.count

    get(url_for(controller: '/website_translation_offers', action: :new_invitation, website_id: website.id,
                id: website_translation_offer.id, translator_id: translator.id))
    assert_response :success

    check_emails_delivered(0) # up to now, no emails

    # no user password, because the user has already signed-up
    post(url_for(controller: '/website_translation_offers', action: :create_invitation, website_id: website.id,
                 id: website_translation_offer.id, translator_id: translator.id),
         website_translation_offer: { invitation: 'hello there' }, title: 'website title', description: 'about this')
    assert_response :redirect

    website_translation_offer.reload
    assert_equal 1, website_translation_offer.website_translation_contracts.length

    contract = website_translation_offer.website_translation_contracts[0]
    assert_equal 1, contract.messages.length

    assert_match(/I would like you to translate my website/, contract.messages[0].body)

    check_emails_delivered(1) # only one to the translator

    translator.reload
    assert_equal translator_reminders + 1, translator.reminders.count

    website.reload
    assert_equal 0, website.anon

    # see that we are still logged in
    get(url_for(controller: '/website_translation_offers', action: :show, website_id: website.id, id: website_translation_offer.id))
    assert_response :success

  end

  def test_create_anon_login_to_support

    Website.destroy_all
    WebsiteTranslationOffer.destroy_all
    WebsiteTranslationContract.destroy_all
    CmsRequest.destroy_all
    ManagedWork.delete_all
    PendingMoneyTransaction.delete_all

    users_count = User.count

    init_email_deliveries

    existing_client = users(:amir)

    url = 'http://www.sample.com'
    title = 'the name of the project'
    description = 'what we are going to do in the project'
    platform_kind = WEBSITE_DRUPAL
    pickup_type = PICKUP_BY_RPC_POST
    notifications = WEBSITE_NOTIFY_DELIVERY
    interview_translators = 0

    language_pairs = [[languages(:English), languages(:Spanish)], [languages(:English), languages(:French)]]
    language_names = language_names_args(language_pairs)

    # complete request
    post url_for(controller: '/websites', action: :create_by_cms, format: :xml),
         params: {
           create_account: 1, anon: 1, url: url, title: title, description: description,
           interview_translators: interview_translators, platform_kind: platform_kind, pickup_type: pickup_type, notifications: notifications,
           project_kind: PRODUCTION_CMS_WEBSITE,
           cms_kind: CMS_KIND_WORDPRESS, cms_description: 'WordPress 2.1', is_verified: 1, ignore_languages: 1
         }
    assert_response :success

    xml = get_xml_tree(@response.body)

    website = assigns(:website)
    assert website
    assert_element_attribute(website.id.to_s, xml.root.elements['website'], 'id')
    assert_element_attribute(website.accesskey.to_s, xml.root.elements['website'], 'accesskey')
    assert_equal website.interview_translators, interview_translators
    assert_equal PRODUCTION_CMS_WEBSITE, website.project_kind
    assert_equal CMS_KIND_WORDPRESS, website.cms_kind
    assert_equal 'WordPress 2.1', website.cms_description
    assert_equal 1, website.free_support

    assert_equal notifications, website.notifications

    assert_equal 0, website.website_translation_offers.length

    check_emails_delivered(0) # no one to deliver the email

    assert_equal users_count + 1, User.count

    # verify the new client's status
    user = website.client

    # assert_equal USER_STATUS_REGISTERED, user.userstatus
    assert_equal 1, user.anon

    # add a language
    language_pairs = [[languages(:English), languages(:Spanish)]]
    new_language_names = language_names_args(language_pairs)

    post url_for(controller: '/websites', action: :update_by_cms, id: website.id, format: :xml),
         params: { accesskey: website.accesskey }.merge(new_language_names)
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute(website.id.to_s, xml.root.elements['website'], 'id')

    website.reload
    assert_equal language_pairs.length, website.website_translation_offers.length

    website_translation_offer = website.website_translation_offers[0]

    UserSession.delete_all
    user_session_count = UserSession.count

    assert_equal user_session_count + 0, UserSession.count

    # create a support ticket

    get(url_for(controller: '/support', wid: website.id, accesskey: website.accesskey))
    assert_response :success

    assert_equal user_session_count + 1, UserSession.count

    get(url_for(controller: '/support', action: :new))
    assert_response :redirect

    get(url_for(controller: '/users', action: :signup, return_to: url_for(controller: '/support', action: :new)))
    assert_response :success

    # incomplete details
    post url_for(controller: '/users', action: :update_name_and_email),
         params: { lname: 'smith', email: 'js@mail.com', create_account: 1, back: 'back' } # 'return' is not a recognizable path
    assert_response :success

    check_emails_delivered(0)

    # full details
    post url_for(controller: '/users', action: :update_name_and_email),
         params: { email1: existing_client.email, password: get_user_test_password(existing_client), create_account: 0, back: 'back' } # 'return' is not a recognizable path
    assert_response :redirect

    check_emails_delivered(0) # the client gets a welcome email

    user = website.reload.client
    assert user.anon != 1

    # 2. with accesskey - ok
    get(url_for(controller: '/website_translation_offers', action: :show, website_id: website.id, id: website_translation_offer.id,
                accesskey: website.accesskey, compact: 1))
    assert_response :success

    user_session = UserSession.all.to_a[-1]
    assert_equal COMPACT_SESSION, user_session.display

    assert_equal 0, website_translation_offer.website_translation_contracts.length

    # invite a translator
    translator_contracts = assigns(:translator_contracts)
    translators = assigns(:translators)

    assert translator_contracts
    assert translators
    assert !translators.empty?

    translator = translators[0]

    translator_reminders = translator.reminders.count

    get(url_for(controller: '/website_translation_offers', action: :new_invitation, website_id: website.id,
                id: website_translation_offer.id, translator_id: translator.id))
    assert_response :success

    check_emails_delivered(0) # up to now, no emails

    # no user password, because the user has already signed-up
    post(url_for(controller: '/website_translation_offers', action: :create_invitation, website_id: website.id,
                 id: website_translation_offer.id, translator_id: translator.id),
         website_translation_offer: { invitation: 'hello there' }, title: 'website title', description: 'about this')
    assert_response :redirect

    website_translation_offer.reload
    assert_equal 1, website_translation_offer.website_translation_contracts.length

    contract = website_translation_offer.website_translation_contracts[0]
    assert_equal 1, contract.messages.length
    website.reload
    assert_equal 0, website.anon
    assert_match(/I would like you to translate my website/, contract.messages[0].body)

    check_emails_delivered(1) # only one to the translator

    translator.reload
    assert_equal translator_reminders + 1, translator.reminders.count

    # see that we are still logged in
    get(url_for(controller: '/website_translation_offers', action: :show, website_id: website.id, id: website_translation_offer.id))
    assert_response :success

  end

  def test_create_anon_and_open_for_applications

    Website.destroy_all
    WebsiteTranslationOffer.destroy_all
    WebsiteTranslationContract.destroy_all
    CmsRequest.destroy_all
    ManagedWork.delete_all
    SentNotification.delete_all
    PendingMoneyTransaction.delete_all

    users_count = User.count

    init_email_deliveries

    checker = PeriodicChecker.new(Time.now)

    existing_client = users(:amir)

    url = 'http://www.sample.com'
    title = 'the name of the project'
    description = 'what we are going to do in the project'
    platform_kind = WEBSITE_DRUPAL
    pickup_type = PICKUP_BY_RPC_POST
    notifications = WEBSITE_NOTIFY_DELIVERY
    interview_translators = 0

    language_pairs = [[languages(:English), languages(:Spanish)], [languages(:English), languages(:French)]]
    language_names = language_names_args(language_pairs)

    # complete request
    post url_for(controller: '/websites', action: :create_by_cms, format: :xml),
         params: {
           create_account: 1, anon: 1, url: url, title: title, description: description,
           interview_translators: interview_translators, platform_kind: platform_kind, pickup_type: pickup_type, notifications: notifications,
           project_kind: PRODUCTION_CMS_WEBSITE,
           cms_kind: CMS_KIND_WORDPRESS, cms_description: 'WordPress 2.1', is_verified: 1, ignore_languages: 1
         }
    assert_response :success

    xml = get_xml_tree(@response.body)

    website = assigns(:website)
    assert website
    assert_element_attribute(website.id.to_s, xml.root.elements['website'], 'id')
    assert_element_attribute(website.accesskey.to_s, xml.root.elements['website'], 'accesskey')
    assert_equal website.interview_translators, interview_translators
    assert_equal PRODUCTION_CMS_WEBSITE, website.project_kind
    assert_equal CMS_KIND_WORDPRESS, website.cms_kind
    assert_equal 'WordPress 2.1', website.cms_description
    assert_equal 1, website.free_support

    assert_equal notifications, website.notifications

    assert_equal 0, website.website_translation_offers.length

    check_emails_delivered(0) # no one to deliver the email

    assert_equal users_count + 1, User.count

    # verify the new client's status
    user = website.client
    # assert_equal USER_STATUS_REGISTERED, user.userstatus
    assert_equal 1, user.anon

    # add a language
    language_pairs = [[languages(:English), languages(:Spanish)]]
    new_language_names = language_names_args(language_pairs)

    post url_for(controller: '/websites', action: :update_by_cms, id: website.id, format: :xml),
         params: { accesskey: website.accesskey }.merge(new_language_names)
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute(website.id.to_s, xml.root.elements['website'], 'id')

    website.reload
    assert_equal language_pairs.length, website.website_translation_offers.length

    website_translation_offer = website.website_translation_offers[0]

    UserSession.delete_all
    user_session_count = UserSession.count

    assert_equal user_session_count + 0, UserSession.count

    # 2. with accesskey - ok
    get(url_for(controller: '/website_translation_offers', action: :show, website_id: website.id, id: website_translation_offer.id,
                accesskey: website.accesskey, compact: 1))
    assert_response :success

    assert_equal user_session_count + 1, UserSession.count

    user_session = UserSession.all.to_a[-1]
    assert_equal COMPACT_SESSION, user_session.display

    # no new session
    assert_equal user_session_count + 1, UserSession.count

    assert_equal 0, website_translation_offer.website_translation_contracts.length

    assert_select 'div#welcome-cms'

    # --- before, transaltors don't see this project
    translator = users(:orit)
    assert_equal DAILY_RELEVANT_PROJECTS_NOTIFICATION, (translator.notifications & DAILY_RELEVANT_PROJECTS_NOTIFICATION)

    assert_equal 0, translator.open_website_translation_offers.length

    get(url_for(controller: '/website_translation_offers', action: :enter_details, website_id: website.id, id: website_translation_offer.id))
    assert_response :success

    assert_equal 1, website.anon
    assert_equal 1, user.anon

    assert_nil website_translation_offer.invitation
    assert_equal TRANSLATION_OFFER_CLOSED, website_translation_offer.status

    # no emails being sent
    cnt = checker.per_profile_mailer
    assert_equal 0, cnt

    category = categories(:financial)

    init_email_deliveries

    post(url_for(controller: '/website_translation_offers', action: :update_details, website_id: website.id,
                 id: website_translation_offer.id, format: :js),
         website_translation_offer: {
           sample_text: 'This is what I want to do'
         },
         title: 'website title',
         description: 'about this',
         category_id: category.id,
         fname: 'jack', lname: 'job', email: 'jack@jobs.com', create_account: 1)
    assert_response :success

    # One e-mail is sent to the client and 2 e-mails are sent to the 2 translators
    check_emails_delivered(3)

    website.reload
    assert_equal category, website.category

    user.reload
    website_translation_offer.reload

    assert_equal TRANSLATION_OFFER_OPEN, website_translation_offer.status

    assert_equal 0, website.anon
    assert_equal 0, user.anon

    assert_equal 'This is what I want to do', website_translation_offer.sample_text

    # Previously, the "Invite all translators" button only changed the
    # WebsiteTranslationOffer status to TRANSLATION_OFFER_OPEN, so translators
    # would be able to see it in their "Open Work" page. Now, that button really
    # invites all translators. Translators invited for a project do not
    # see that project in their "Open Work" page.
    assert_equal 0, translator.open_website_translation_offers.length
  end

  def test_update_languages_by_cms

    Website.destroy_all
    WebsiteTranslationOffer.destroy_all
    WebsiteTranslationContract.destroy_all
    CmsRequest.destroy_all
    ManagedWork.delete_all
    PendingMoneyTransaction.delete_all

    users_count = User.count

    init_email_deliveries

    email = 'someone@sample.com'
    fname = 'rosh'
    lname = 'hashana'
    url = 'http://www.sample.com'
    title = 'the name of the project'
    description = 'what we are going to do in the project'
    platform_kind = WEBSITE_DRUPAL
    pickup_type = PICKUP_BY_RPC_POST
    notifications = WEBSITE_NOTIFY_DELIVERY
    interview_translators = 0

    language_pairs = [[languages(:English), languages(:Spanish)], [languages(:English), languages(:French)]]
    language_names = language_names_args(language_pairs)

    # complete request
    post url_for(controller: '/websites', action: :create_by_cms, format: :xml),
         params: {
           email: email, fname: fname, lname: lname, create_account: 1, url: url, title: title, description: description,
           interview_translators: interview_translators, platform_kind: platform_kind, pickup_type: pickup_type, notifications: notifications,
           project_kind: PRODUCTION_CMS_WEBSITE,
           cms_kind: CMS_KIND_WORDPRESS, cms_description: 'WordPress 2.1', is_verified: 1
         }.merge(language_names)
    assert_response :success

    xml = get_xml_tree(@response.body)

    website = assigns(:website)
    assert website
    assert_element_attribute(website.id.to_s, xml.root.elements['website'], 'id')
    assert_element_attribute(website.accesskey.to_s, xml.root.elements['website'], 'accesskey')
    assert_equal website.interview_translators, interview_translators
    assert_equal PRODUCTION_CMS_WEBSITE, website.project_kind
    assert_equal CMS_KIND_WORDPRESS, website.cms_kind
    assert_equal 'WordPress 2.1', website.cms_description

    assert_equal notifications, website.notifications

    assert_equal language_pairs.length, website.website_translation_offers.length
    website.website_translation_offers.each { |offer| assert_equal TRANSLATION_OFFER_OPEN, offer.status }

    assert_equal users_count + 1, User.count

    # verify the new client's status
    user = website.client
    assert_equal USER_STATUS_REGISTERED, user.userstatus
  end

  def test_create_test_by_cms
    Website.destroy_all
    WebsiteTranslationOffer.destroy_all
    WebsiteTranslationContract.destroy_all
    CmsRequest.destroy_all
    ManagedWork.delete_all
    PendingMoneyTransaction.delete_all

    init_email_deliveries

    # --- make sure that translators still don't see the offers for this client
    translator = users(:pt1)
    prev_open_offers = translator.open_website_translation_offers.length

    normal_translator = users(:orit)
    prev_open_offers_for_normal = normal_translator.open_website_translation_offers.length

    client = users(:amir)

    url = 'http://www.sample.com'
    title = 'a test project'
    description = 'what we are going to do in the project'
    platform_kind = WEBSITE_DRUPAL
    pickup_type = PICKUP_BY_RPC_POST
    notifications = WEBSITE_NOTIFY_DELIVERY
    interview_translators = 1

    language_pairs = [[languages(:English), languages(:Spanish)], [languages(:English), languages(:French)]]
    language_names = language_names_args(language_pairs)

    # complete request
    post url_for(controller: '/websites', action: :create_by_cms, format: :xml),
         params: {
           email: client.email, password: get_user_test_password(client), create_account: 0, url: url, title: title, description: description,
           interview_translators: interview_translators, platform_kind: platform_kind, pickup_type: pickup_type, notifications: notifications,
           project_kind: TEST_CMS_WEBSITE,
           cms_kind: CMS_KIND_WORDPRESS, cms_description: 'WordPress 2.1'
         }.merge(language_names)
    assert_response :success

    xml = get_xml_tree(@response.body)

    website = assigns(:website)
    assert website
    assert_element_attribute(website.id.to_s, xml.root.elements['website'], 'id')
    assert_element_attribute(website.accesskey.to_s, xml.root.elements['website'], 'accesskey')
    assert_equal website.interview_translators, interview_translators
    assert_equal TEST_CMS_WEBSITE, website.project_kind
    assert_equal CMS_KIND_WORDPRESS, website.cms_kind
    assert_equal 'WordPress 2.1', website.cms_description

    assert_equal notifications, website.notifications

    assert_equal language_pairs.length, website.website_translation_offers.length
    website.website_translation_offers.each do |offer|
      assert_equal TRANSLATION_OFFER_OPEN, offer.status
    end

    check_emails_delivered(0)

    # --- make sure that translators still don't see the offers for this client
    assert_equal prev_open_offers_for_normal, normal_translator.open_website_translation_offers.length
    assert_equal prev_open_offers + language_pairs.length, translator.open_website_translation_offers.length

    # --- log in as a translator and apply to these offers
    session = login(translator)

    get(url_for(controller: '/translator', action: :open_work))
    assert_response :success

    open_website_translation_offers = assigns(:open_website_translation_offers)
    assert open_website_translation_offers
    assert_equal 2, open_website_translation_offers.length

    open_website_translation_offers.each do |offer|
      assert_equal website, offer.website

      get(url_for(controller: '/website_translation_contracts', action: :new, website_id: offer.website.id,
                  website_translation_offer_id: offer.id))
      assert_response :success

      post(url_for(controller: '/website_translation_contracts', action: :create, website_id: offer.website.id,
                   website_translation_offer_id: offer.id),
           apply: 1, message: 'I want to try', website_translation_contract: { amount: 0.10 })
      assert_response :redirect

      offer.reload
      assert_equal 1, offer.website_translation_contracts.length

      check_emails_delivered(1)

      offer.website_translation_contracts.each do |c|

        assert_equal TRANSLATION_CONTRACT_REQUESTED, c.status
        assert_equal translator, c.translator
        assert_equal 1, c.reminders.length

        get(url_for(controller: '/website_translation_contracts', action: :show, id: c.id, website_id: offer.website.id,
                    website_translation_offer_id: offer.id))
        assert_response :success

      end
    end

    assert_equal open_website_translation_offers.length, website.reminders.length

    logout(session)

    # --- log in as a supporter and assign a translator for this job (check client notifications) ---
    session = login(client)

    offers = website.website_translation_offers
    assert offers
    assert_equal 2, offers.length

    offers.each do |offer|
      assert_equal website, offer.website
      assert_equal 1, offer.website_translation_contracts.length

      offer.website_translation_contracts.each do |c|
        assert_equal TRANSLATION_CONTRACT_REQUESTED, c.status

        assert_equal 1, c.reminders.length
        client_reminders = client.reminders.length

        post(url_for(controller: '/website_translation_contracts', action: :update_application_status, website_id: offer.website.id,
                     website_translation_offer_id: offer.id, id: c.id),
             status: TRANSLATION_CONTRACT_ACCEPTED)
        assert_response :redirect

        c.reload
        assert_equal TRANSLATION_CONTRACT_ACCEPTED, c.status

        client.reload
        c.reload
        client.reload
        assert_equal 0, c.reminders.length
        assert_equal client_reminders - 1, client.reminders.length

        # the translator is notified and we send a what-next message to both client and translator
        check_emails_delivered(3)
      end
    end

    logout(session)

  end

  def test_create_with_affiliate_code_by_cms
    Website.destroy_all
    WebsiteTranslationOffer.destroy_all
    WebsiteTranslationContract.destroy_all
    CmsRequest.destroy_all
    ManagedWork.delete_all
    PendingMoneyTransaction.delete_all

    init_email_deliveries

    # --- make sure that translators still don't see the offers for this client
    affiliate = users(:amir)

    email = 'someone_else@sample.com'
    fname = 'rosh'
    lname = 'hashana'
    url = 'http://www.sample.com'
    title = 'the name of the project'
    description = 'what we are going to do in the project'
    platform_kind = WEBSITE_DRUPAL
    pickup_type = PICKUP_BY_RPC_POST
    notifications = WEBSITE_NOTIFY_DELIVERY
    interview_translators = 0

    language_pairs = [[languages(:English), languages(:Spanish)], [languages(:English), languages(:French)]]
    language_names = language_names_args(language_pairs)

    users_count = User.count

    check_emails_delivered(0)
    # complete request
    post url_for(controller: '/websites', action: :create_by_cms, format: :xml),
         params: {
           email: email, fname: fname, lname: lname, create_account: 1, url: url, title: title, description: description,
           interview_translators: interview_translators, platform_kind: platform_kind, pickup_type: pickup_type, notifications: notifications,
           project_kind: PRODUCTION_CMS_WEBSITE,
           affiliate_id: affiliate.id, affiliate_key: affiliate.affiliate_key,
           cms_kind: CMS_KIND_WORDPRESS, cms_description: 'WordPress 2.1'
         }.merge(language_names)
    assert_response :success

    xml = get_xml_tree(@response.body)

    website = assigns(:website)
    assert website
    assert_element_attribute(website.id.to_s, xml.root.elements['website'], 'id')
    assert_element_attribute(website.accesskey.to_s, xml.root.elements['website'], 'accesskey')
    assert_equal website.interview_translators, interview_translators
    assert_equal PRODUCTION_CMS_WEBSITE, website.project_kind
    assert_equal CMS_KIND_WORDPRESS, website.cms_kind
    assert_equal 'WordPress 2.1', website.cms_description

    assert_equal notifications, website.notifications

    assert_equal language_pairs.length, website.website_translation_offers.length
    website.website_translation_offers.each { |offer| assert_equal TRANSLATION_OFFER_OPEN, offer.status }

    assert_equal users_count + 1, User.count

    # verify the new client's status
    user = website.client
    assert_equal USER_STATUS_NEW, user.userstatus
    assert_equal affiliate, user.affiliate
  end

  def test_update_affiliate_code_by_cms
    Website.destroy_all
    WebsiteTranslationOffer.destroy_all
    WebsiteTranslationContract.destroy_all
    CmsRequest.destroy_all
    ManagedWork.delete_all
    PendingMoneyTransaction.delete_all

    init_email_deliveries

    # --- make sure that translators still don't see the offers for this client
    affiliate = users(:amir)

    email = 'another_one@sample.com'
    fname = 'another'
    lname = 'one'
    url = 'http://www.sample1.com'
    title = 'the name of the project'
    description = 'what we are going to do in the project'
    platform_kind = WEBSITE_DRUPAL
    pickup_type = PICKUP_BY_RPC_POST
    notifications = WEBSITE_NOTIFY_DELIVERY
    interview_translators = 0

    language_pairs = [[languages(:English), languages(:Spanish)], [languages(:English), languages(:French)]]
    language_names = language_names_args(language_pairs)

    users_count = User.count

    check_emails_delivered(0)
    # complete request
    post url_for(controller: '/websites', action: :create_by_cms, format: :xml),
         params: {
           email: email, fname: fname, lname: lname, create_account: 1, url: url, title: title, description: description,
           interview_translators: interview_translators, platform_kind: platform_kind, pickup_type: pickup_type, notifications: notifications,
           project_kind: PRODUCTION_CMS_WEBSITE,
           cms_kind: CMS_KIND_WORDPRESS, cms_description: 'WordPress 2.1'
         }.merge(language_names)
    assert_response :success

    xml = get_xml_tree(@response.body)

    website = assigns(:website)
    assert website
    assert_element_attribute(website.id.to_s, xml.root.elements['website'], 'id')
    assert_element_attribute(website.accesskey.to_s, xml.root.elements['website'], 'accesskey')
    assert_equal website.interview_translators, interview_translators
    assert_equal PRODUCTION_CMS_WEBSITE, website.project_kind
    assert_equal CMS_KIND_WORDPRESS, website.cms_kind
    assert_equal 'WordPress 2.1', website.cms_description

    assert_equal notifications, website.notifications

    assert_equal language_pairs.length, website.website_translation_offers.length
    website.website_translation_offers.each { |offer| assert_equal TRANSLATION_OFFER_OPEN, offer.status }

    assert_equal users_count + 1, User.count

    # verify the new client's status
    user = website.client
    assert_equal USER_STATUS_NEW, user.userstatus
    assert_nil user.affiliate

    # --- add the affiliate information for this user ---
    post url_for(controller: '/websites', action: :update_by_cms, id: website.id, format: :xml),
         params: { accesskey: website.accesskey, affiliate_id: affiliate.id, affiliate_key: affiliate.affiliate_key }
    assert_response :success
    # xml = get_xml_tree(@response.body)
    # assert_element_attribute(website.id.to_s, xml.root.elements['website'],'id')

    user.reload
    assert_equal affiliate, user.affiliate
  end

  def test_partner_create_by_cms
    Website.destroy_all
    WebsiteTranslationOffer.destroy_all
    WebsiteTranslationContract.destroy_all
    CmsRequest.destroy_all
    ManagedWork.delete_all
    PendingMoneyTransaction.delete_all

    init_email_deliveries

    # --- make sure that translators still don't see the offers for this client
    partner = users(:shark)

    uid = partner.id

    email = 'someone_else@sample.com'
    fname = 'rosh'
    lname = 'hashana'
    url = 'http://www.sample.com'
    title = 'the name of the project'
    description = 'what we are going to do in the project'
    platform_kind = WEBSITE_DRUPAL
    pickup_type = PICKUP_BY_RPC_POST
    notifications = WEBSITE_NOTIFY_DELIVERY
    interview_translators = 0

    language_pairs = [[languages(:English), languages(:Spanish)], [languages(:English), languages(:French)]]
    language_names = language_names_args(language_pairs)

    users_count = User.count

    check_emails_delivered(0)
    # complete request
    post url_for(controller: '/websites', action: :create_by_cms, format: :xml),
         params: {
           email: partner.email, password: get_user_test_password(partner), fname: '', lname: '', create_account: 0, url: url,
           title: title, description: description,
           interview_translators: interview_translators, platform_kind: platform_kind, pickup_type: pickup_type, notifications: notifications,
           project_kind: PRODUCTION_CMS_WEBSITE,
           cms_kind: CMS_KIND_WORDPRESS, cms_description: 'WordPress 2.1'
         }.merge(language_names)
    assert_response :success

    xml = get_xml_tree(@response.body)

    website = assigns(:website)
    assert website
    assert_element_attribute(website.id.to_s, xml.root.elements['website'], 'id')
    assert_element_attribute(website.accesskey.to_s, xml.root.elements['website'], 'accesskey')
    assert_equal website.interview_translators, interview_translators
    assert_equal PRODUCTION_CMS_WEBSITE, website.project_kind
    assert_equal CMS_KIND_WORDPRESS, website.cms_kind
    assert_equal 'WordPress 2.1', website.cms_description

    assert_equal notifications, website.notifications

    assert_equal language_pairs.length, website.website_translation_offers.length
    website.website_translation_offers.each { |offer| assert_equal TRANSLATION_OFFER_OPEN, offer.status }

    check_emails_delivered(0)

    u = User.find(uid)
    assert_equal Client, u.class

  end

  def test_create_for_support

    Website.destroy_all
    WebsiteTranslationOffer.destroy_all
    WebsiteTranslationContract.destroy_all
    CmsRequest.destroy_all
    ManagedWork.delete_all
    PendingMoneyTransaction.delete_all

    users_count = User.count

    init_email_deliveries

    email = 'someone1@sample.com'
    fname = 'rosh'
    lname = 'hashana'
    url = 'http://www.sample.com'
    title = 'the name of the project'
    description = 'what we are going to do in the project'
    platform_kind = WEBSITE_DRUPAL
    pickup_type = PICKUP_BY_RPC_POST
    notifications = WEBSITE_NOTIFY_DELIVERY
    interview_translators = 0

    # complete request
    post url_for(controller: '/websites', action: :create_by_cms, format: :xml),
         params: {
           email: email, fname: fname, lname: lname, create_account: 1, url: url, title: title, description: description,
           interview_translators: interview_translators, platform_kind: platform_kind, pickup_type: pickup_type, notifications: notifications,
           project_kind: PRODUCTION_CMS_WEBSITE,
           cms_kind: CMS_KIND_WORDPRESS, cms_description: 'WordPress 2.1', is_verified: 1,
           ignore_languages: 1
         }
    assert_response :success

    xml = get_xml_tree(@response.body)

    website = assigns(:website)
    assert website
    assert_element_attribute(website.id.to_s, xml.root.elements['website'], 'id')
    assert_element_attribute(website.accesskey.to_s, xml.root.elements['website'], 'accesskey')
    assert_equal website.interview_translators, interview_translators
    assert_equal PRODUCTION_CMS_WEBSITE, website.project_kind
    assert_equal CMS_KIND_WORDPRESS, website.cms_kind
    assert_equal 'WordPress 2.1', website.cms_description
    assert_equal 0, website.free_support

    assert_equal notifications, website.notifications

    assert_equal 0, website.website_translation_offers.length

    assert_equal users_count + 1, User.count

    # verify the new client's status
    user = website.client
    assert_equal USER_STATUS_REGISTERED, user.userstatus

    old_accesskey = website.accesskey

    # ----- transfer the project to a different user ------

    email1 = 'someone2@sample.com'
    fname1 = 'rosh1'
    lname1 = 'hashana'

    post url_for(controller: '/websites', action: :transfer_account, id: website.id, format: :xml),
         params: { email: email1, fname: fname1, lname: lname1, create_account: 1, accesskey: website.accesskey }
    assert_response :success

    xml = get_xml_tree(@response.body)

    website.reload

    user1 = website.client
    assert_not_equal user, user1

    assert_equal email1, user1.email
    assert_equal fname1, user1.fname
    assert_equal lname1, user1.lname

  end

  def test_use_cms_id
    offer = website_translation_offers(:amir_drupal_rpc_en_es)
    website = offer.website
    client = website.client

    orig_language = languages(:English)
    translation_languages = [languages(:Spanish)]

    fdata_args = {}
    fdata_args['doc_count'] = 0

    idx = 1
    translation_languages.each do |tl|
      fdata_args["to_language#{idx}"] = tl.name
      idx += 1
    end

    title = 'Orig title'
    permlink = 'link1-en'
    note = 'This is what I am asking'
    cms_id = 'cool_id3'
    post url_for(controller: '/cms_requests', action: :create, website_id: website.id, format: 'xml'),
         params: {
           accesskey: website.accesskey,
           orig_language: orig_language.name,
           title: title, permlink: permlink, note: note, cms_id: cms_id
         }.merge(fdata_args)
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert assigns(:tas_request_notification_sent)
    tas_session = assigns(:tas_session)
    assert tas_session

    assert_element_attribute('Upload created', xml.root.elements['result'], 'message')
    cms_request_id = get_element_attribute(xml.root.elements['result'], 'id').to_i

    cms_request = CmsRequest.find(cms_request_id)
    assert cms_request
    assert_equal CMS_REQUEST_WAITING_FOR_PROJECT_CREATION, cms_request.status
    assert_equal 0, cms_request.cms_uploads.length
    assert_equal title, cms_request.title
    assert_equal permlink, cms_request.permlink
    assert_equal 1, cms_request.pending_tas
    assert_equal LAST_TAS_COMMAND_CREATE, cms_request.last_operation
    assert_equal note, cms_request.note
    assert_equal cms_id, cms_request.cms_id

    # see that TAS gets the cms_id
    get(url_for(controller: '/cms_requests', action: :show, id: cms_request.id, website_id: website.id, format: 'xml'))
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute(cms_id, xml.root.elements['cms_request'], 'cms_id')

    # Required for this cms_request to be returned by CmsRequestsController#cms_id
    cms_request.update!(pending_tas: false)

    # check that we can see this request for the cms_id
    get(url_for(controller: '/cms_requests', action: :cms_id, cms_id: cms_id, website_id: website.id, format: 'xml'))
    assert_response :success
    xml = get_xml_tree(@response.body)

    request_ids = xml.root.elements['cms_requests'].elements.collect { |element| element.attributes['id'].to_i }
    assert_equal 1, request_ids.length
    assert_equal cms_request_id, request_ids[0]

    # create another request and see that both appear
    post url_for(controller: '/cms_requests', action: :create, website_id: website.id, format: 'xml'),
         params: {
           accesskey: website.accesskey,
           orig_language: orig_language.name,
           title: title, permlink: permlink, note: note, cms_id: cms_id
         }.merge(fdata_args)
    assert_response :success
    xml = get_xml_tree(@response.body)

    assert_element_attribute('Upload created', xml.root.elements['result'], 'message')
    cms_request_id2 = get_element_attribute(xml.root.elements['result'], 'id').to_i
    cms_request2 = CmsRequest.find(cms_request_id2)
    assert cms_request2

    assert_not_equal cms_request_id2, cms_request_id

    # Required for this cms_request to be returned by CmsRequestsController#cms_id
    cms_request2.update!(pending_tas: false)

    # check that we can see this request for the cms_id
    get(url_for(controller: '/cms_requests', action: :cms_id, cms_id: cms_id, website_id: website.id, format: 'xml'))
    assert_response :success
    xml = get_xml_tree(@response.body)

    request_ids = xml.root.elements['cms_requests'].elements.collect { |element| element.attributes['id'].to_i }
    assert_equal 2, request_ids.length
    assert_equal cms_request_id, request_ids[0]
    assert_equal cms_request_id2, request_ids[1]

    # update the CMS_id
    post url_for(controller: '/cms_requests', action: :update_cms_id, website_id: website.id, format: 'xml'),
         params: {
           accesskey: website.accesskey,
           permlink: permlink,
           from_language: orig_language.name,
           to_language: translation_languages[0].name,
           cms_id: 'New CMS ID',
           dry_run: 1
         }
    assert_response :success
    xml = get_xml_tree(@response.body)

    cms_request.reload
    assert_not_equal 'New CMS ID', cms_request.cms_id

    post url_for(controller: '/cms_requests', action: :update_cms_id, website_id: website.id, format: 'xml'),
         params: {
           accesskey: website.accesskey,
           permlink: permlink,
           from_language: orig_language.name,
           to_language: translation_languages[0].name,
           cms_id: 'New CMS ID'
         }
    assert_response :success
    xml = get_xml_tree(@response.body)

    assert_element_attribute('New CMS ID', xml.root.elements['updated/cms_request'], 'cms_id')
    assert_element_attribute(cms_request.id.to_s, xml.root.elements['updated/cms_request'], 'id')

    cms_request.reload
    assert_equal 'New CMS ID', cms_request.cms_id
  end

  def check_website_pages(website, user, need_login)
    session = login(user) if need_login

    get(url_for(controller: '/wpml/websites', action: :show, id: website.id))
    assert_response :success

    # XML requests should be directed to the legacy website controller
    get(url_for(controller: '/websites', action: :show, id: website.id, format: :xml))
    assert_response :success

    website.website_translation_offers.each do |website_translation_offer|
      if user.has_admin_privileges? || (user[:type] == 'Client')
        get(url_for(controller: '/website_translation_offers', action: :show, website_id: website.id, id: website_translation_offer.id))
        assert_response :success
      end

      website_translation_offer.website_translation_contracts.each do |_website_translation_contract|
        get(url_for(controller: '/website_translation_offers', action: :show, website_id: website.id, id: website_translation_offer.id))
        assert_response :success
      end
    end

    logout(session) if need_login
  end

  # ----

  def language_names_args(language_pairs)
    idx = 1
    language_names = {}
    language_pairs.each do |language_pair|
      language_names["from_language#{idx}"] = language_pair[0].name
      language_names["to_language#{idx}"] = language_pair[1].name
      idx += 1
    end
    language_names
  end

  def debug_print(state)
    puts "\n --- #{state} ---"
    CmsRequest.all.each do |c|
      puts "cms_request.#{c.id}, translating to: #{(c.cms_target_languages.collect { |l| l.language.name }).join(', ')}, notifications: #{(c.sent_notifications.collect { |s| s.user.email }).join(', ')}"
    end
    puts "\n"
  end

end
# after release, the word count should be set to the revision's word count
