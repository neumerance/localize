require "#{File.dirname(__FILE__)}/../test_helper"

class InstantTranslationProject < ActionDispatch::IntegrationTest
  fixtures :users, :languages, :alias_profiles, :currencies

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

    login(@client)

    # Create the project
    create_project

    login @translator
    translate_project

    login @reviewer
    review_project

    login @client
    get_translations
  end

  def create_project
    # home
    get('/client')
    assert_response :success

    # new
    get(new_web_message_url)
    assert_response :success

    # Alias can't access this page
    [@alias_cant_do, @alias_cant_edit].each do |user|
      login user
      get(new_web_message_url)
      assert_response :redirect
    end
    login @client

    # pre - create
    name = 'Test project'
    text = 'one two three'
    instructions = 'translate the text'
    language_id = 1
    post(pre_create_web_messages_url, web_message: { comment: instructions, client_language_id: language_id, client_body: text, name: name })
    assert_response :success

    # select languages
    languages = [2, 4]
    languages_param = {}
    languages.each { |l| languages_param[l] = 1 }
    post(select_to_languages_web_messages_url(format: :js), language: languages_param, review: 1)
    assert_response :success

    # create
    assert_difference 'WebMessage.count', languages.size do
      post(web_messages_url)
      assert_response :success
    end

    @web_message = WebMessage.last
  end

  def translate_project
    WebMessage.all[-2..-1].each do |web_message|
      get('/translator')
      assert_response :success
      assert_select "a[href='#{web_messages_path}']"

      get(web_messages_path)
      assert_response :success
      assert_select "a[href='#{hold_for_translation_web_message_path(web_message)}']"

      post(hold_for_translation_web_message_path(web_message))
      assert_response :success
      assert_equal web_message, assigns(:web_message)

      post(final_review_web_message_url(web_message), plaintext: 1, body: 'Translation')
      assert_response :success

      assert_difference('ActionMailer::Base.deliveries.length', 1) do
        put(web_message_url(web_message), body: 'translation', plaintext: 1, ignore_warnings: 1)
        assert_response :redirect
      end
    end
  end

  def review_project
    WebMessage.all[-2..-1].each do |web_message|
      get('/translator')
      assert_response :success
      assert_select "a[href='#{review_index_web_messages_path}']"

      get(review_index_web_messages_path)
      assert_response :success
      assert_select "a[href='#{hold_for_review_web_message_path(web_message)}']"

      post(hold_for_review_web_message_path(web_message))
      assert_response :redirect
      assert_equal web_message, assigns(:web_message)

      get(review_web_message_url(web_message))
      assert :success

      assert_difference('ActionMailer::Base.deliveries.length', 1) do
        post(review_complete_web_message_url(web_message))
        assert :success
      end

      web_message.reload
      assert_equal 2, web_message.managed_work.translation_status
    end
  end

  def get_translations
    # Go to web messages page
    get(web_messages_path)
    web_messages = assigns(:messages)
    assert :success
    assert_select 'td', text: 'Translated and reviewed', count: 2

    web_messages.each do |wm|
      get translation_web_message_url(wm)
      assert_response :success

      get web_message_url(wm)
      assert_response :success

      # test alias access
      login(@alias_cant_do)
      get translation_web_message_url(wm)
      assert_response :redirect
      get web_message_url(wm)
      assert_response :redirect
      login(@alias_cant_edit)
      get translation_web_message_url(wm)
      assert_response :success
      get web_message_url(wm)
      assert_response :success
      login(@client)

    end
  end
end
