require "#{File.dirname(__FILE__)}/../test_helper"

class TranslatorLanguageTest < ActionDispatch::IntegrationTest
  fixtures :users, :languages

  def test_translator_language_addition
    supporter = users(:supporter)
    ssession = login(supporter)

    translator = users(:newbi)
    session = login(translator)

    # translator.translator_languages.delete_all
    TranslatorLanguage.destroy_all

    assert_equal 0, translator.translator_languages.length

    check_available_languages(0)

    # see how many todo items there are. After adding the languages, there should be two less
    orig_todos = translator.todos
    assert orig_todos[0] >= 2

    # go to the languages setup page
    get(url_for(controller: :users, action: :translator_languages, id: translator.id),
        session: session)
    assert_response :success

    # add the to-language box
    from_language = languages(:English)
    xml_http_request(:post, url_for(controller: :users, action: :add_from_languages, id: translator.id),
                     session: session, from_lang_id: from_language.id)
    assert_response :success

    translator.reload
    assert_equal 1, translator.translator_languages.length
    tl = translator.translator_languages[0]

    # remove it
    xml_http_request(:post, url_for(controller: :users, action: :del_language, id: translator.id),
                     session: session, tl_id: tl.id)
    assert_response :success

    translator.reload
    assert_equal 0, translator.translator_languages.length

    # add again
    from_language = languages(:English)
    xml_http_request(:post, url_for(controller: :users, action: :add_from_languages, id: translator.id),
                     session: session, from_lang_id: from_language.id)
    assert_response :success

    translator.reload
    assert_equal 1, translator.translator_languages.length
    tl = translator.translator_languages[0]

    add_translation_language_document(session, translator, tl)

    check_available_languages(0)

    approve_pending_translation_languages(ssession, supporter, tl)
    translator.reload
    assert_equal orig_todos[0] - 1, translator.todos[0]
    assert_equal 1, translator.from_languages.count
    assert_equal from_language, translator.from_languages.first

    # only added 'from' language
    check_available_languages(0)

    # add a language to be denied
    to_language = languages(:French)
    xml_http_request(:post, url_for(controller: :users, action: :add_to_languages, id: translator.id),
                     session: session, to_lang_id: to_language.id)
    assert_response :success

    translator.reload
    assert_equal 2, translator.translator_languages.length
    tl = translator.translator_languages[-1]

    add_translation_language_document(session, translator, tl)

    decline_pending_translation_languages(ssession, supporter, tl)
    translator.reload
    assert_equal orig_todos[0] - 1, translator.todos[0]
    assert_equal 0, translator.to_languages.length

    # add the from-language box to be accepted
    to_language = languages(:Spanish)
    xml_http_request(:post, url_for(controller: :users, action: :add_to_languages, id: translator.id),
                     session: session, to_lang_id: to_language.id)
    assert_response :success

    translator.reload
    assert_equal 3, translator.translator_languages.length
    tl = translator.translator_languages[-1]

    add_translation_language_document(session, translator, tl)

    approve_pending_translation_languages(ssession, supporter, tl)
    translator.reload
    assert_equal orig_todos[0] - 2, translator.todos[0]
    assert_equal 1, translator.to_languages.length
    assert_equal to_language, translator.to_languages.first

    # puts "--- starting with available_for_cms '0'"
    translator.update_attributes(userstatus: USER_STATUS_REGISTERED)
    check_available_languages(1)
    check_available_languages(0, 1)
    check_available_languages(0, 2)

    # check that we have qualified translators
    # puts "changing userstatus to USER_STATUS_QUALIFIED"
    translator.update_attributes(userstatus: USER_STATUS_QUALIFIED)
    translator.update_attributes(scanned_for_languages: 0)
    check_available_languages(1, 1)
    check_available_languages(0, 2)

    # decline the application - no more translator
    decline_pending_translation_languages(ssession, supporter, tl)
    check_available_languages(0)
  end

  def add_translation_language_document(session, translator, tl)
    init_email_deliveries

    assert_equal tl.status, TRANSLATOR_LANGUAGE_NEW

    # now, add a document and complete the request
    tl_description = 'Some description'
    upload_description = 'Document description'
    fname = 'sample/Initial/proj5.xml'
    multipart_post(
      url_for(controller: :users, action: :add_language_document, id: translator.id, target: 'frame'),
      session: session,
      translator_language_id: tl.id,
      tl_description: tl_description,
      description: upload_description,
      uploaded_data: fixture_file_upload(fname, 'application/octet-stream'),
      format: :js
    )
    assert_response :success

    tl.reload
    assert_equal tl.description, tl_description
    assert tl.translator_language_documents
    assert_equal 1, tl.translator_language_documents.length
    assert_equal tl.translator_language_documents[0].description, upload_description
    assert_equal tl.status, TRANSLATOR_LANGUAGE_REQUEST_REVIEW

    # make sure that all admins are notified
    check_emails_delivered(Admin.count)

    assert Admin.count > 1

  end

  def approve_pending_translation_languages(session, _supporter, tl)
    get(url_for(controller: :supporter), session: session)
    assert_response :success

    post(url_for(controller: :supporter, action: :approve_translator_language, id: tl.id))
    assert_response :redirect

    tl.reload
    assert_equal TRANSLATOR_LANGUAGE_APPROVED, tl.status
  end

  def decline_pending_translation_languages(session, _supporter, tl)
    get(url_for(controller: :supporter), session: session)
    assert_response :success

    post(url_for(controller: :supporter, action: :decline_translator_language, id: tl.id))
    assert_response :redirect

    tl.reload
    assert_equal TRANSLATOR_LANGUAGE_DECLINED, tl.status
  end

  def check_available_languages(expected_number, qualified = nil)
    res = AvailableLanguage.regenarate(true)
    als = qualified ? AvailableLanguage.where('qualified=?', qualified) : AvailableLanguage.all
    # als.each do |al|
    # puts "--> From #{al.from_language.name} to #{al.to_language.name} (qualified=#{al.qualified})"
    # end
    assert_equal expected_number, als.length

  end
end
