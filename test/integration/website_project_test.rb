require "#{File.dirname(__FILE__)}/../test_helper"

class WebsiteProjectTest < ActionDispatch::IntegrationTest
  include ActionDispatch::TestProcess

  fixtures :users

  # mocking the pickup by TAS
  def tas_mock
    cms_request = CmsRequest.last
    cms_request.update(pending_tas: 0)
    cms_request.cms_target_language.update(status: CMS_TARGET_LANGUAGE_CREATED)
  end

  # Mocking processing by WebTA (otgs-segmenter gem)
  def otgs_segmenter_mock
    cms_request = CmsRequest.last
    cms_request.update(xliff_processed: true)
  end

  # Tests a complete project cycle for a default client.
  def test_client_std_lifecycle
    CmsRequest.any_instance.stubs(:calculate_required_balance).returns([1000, {}, {}, {}])
    std_project_lifecycle(nil)
  end

  # Test a complete project cycle for an alias from the client
  # with full access to modify, pay, and anything else needed.
  def test_alias_full_std_lifecycle
    CmsRequest.any_instance.stubs(:calculate_required_balance).returns([1000, {}, {}, {}])
    std_project_lifecycle(:alias_full)
  end

  def std_project_lifecycle(client_name)
    # Grab the translator and review
    @translator = users(:orit)
    @reviewer = users(:guy)
    # Client and aliases will be defined later.

    ##
    # CMS based requests
    #

    # Create a website
    @website = setup_website

    # Setup aliases; get the client and set aliases to be from that client account
    setup_aliases(client_name)

    # Add french language
    add_language

    # Send some content to translate in spanish and french
    send_content

    # Get translation requests list, doing nothing with the result
    get_translation_requests

    # Set the permlink of a request to something
    set_translation_url

    ##
    # ICanLocalize navigation
    #

    login @client

    # Edit website information
    edit_information

    # Invite the translator for both languages
    invite_translators

    # Bid on both languages
    login @translator
    make_bids

    # Accept both bids
    login @client
    accept_bids

    # Pay
    @client.money_accounts.first.update_attributes(balance: 0)

    get(website_cms_requests_url)
    deposit_money

    # Get a job and translate it
    login @translator
    do_translations

    ##
    # CMS based requests
    #

    # download_translations
    # mark_as_complete

  end

  def setup_website
    # Create the website
    params = {
      # Acc information
      'fname' => 'first name',
      'lname' => 'last name',
      'email' => 'clientemail@mail.com',
      'create_account' => 1,
      'is_verified' => 1,

      # Project information
      'url' => 'http://www.someurl.com',
      'title' => 'Test site',
      'from_language1' => 'English',
      'to_language1' => 'Spanish',
      'pickup_type' => 1,
      'notification' => 1,

      # CMS information
      'platform_kind' => 2,
      'cms_kind' => 1,
      'cms_description' => 'a wordpress'
    }

    assert_difference 'Website.count', 1 do
      post('/websites/create_by_cms.xml', params: params)
      assert_response :success
      assert_select 'website'
    end

    Website.last
  end

  def setup_aliases(client_name)
    # Set the actors
    if client_name.nil?
      @client = @website.client
    else # is an alias from the client
      @client = users(client_name)
      @client.master_account_id = @website.client.id
      @client.save!
    end

    # This aliases will be used eventually to make sure they can't access the proper areas
    @alias_cant_do = users(:alias_cant_do) # This alias has no access permissions
    @alias_cant_edit = users(:alias_cant_edit)
    @alias_cant_pay = users(:alias_cant_pay)
    [@alias_cant_do, @alias_cant_edit, @alias_cant_pay].each do |a|
      a.master_account_id = @client.id
      a.save!
    end
  end

  def add_language
    params = {
      'id' => @website.id,
      'accesskey' => @website.accesskey,
      'from_language1' => 'English',
      'to_language1' => 'Spanish',
      'from_language2' => 'English',
      'to_language2' => 'French'
    }

    assert_no_difference 'Website.count' do
      post('/websites/update_by_cms.xml', params: params)
      assert_response :success
      assert_select 'website'
    end

    @website.reload
    assert_equal 2, @website.website_translation_offers.count
    @website.website_translation_offers.each do |wto|
      assert %w(Spanish French).include? wto.to_language.name
      assert_equal 'English', wto.from_language.name
    end
  end

  def send_content
    # Adds a job for each language
    %w(Spanish French).each do |language|
      params = {
        'accesskey' => @website.accesskey,
        'orig_language' => 'English',
        'title' => 'Content title',
        'doc_count' => 1,
        'key' => 'abcdefg' + language,
        'cms_id' => 'page_1', # Document identifier
        'to_language1' => language,
        'file1' => { uploaded_data: fixture_file_upload("files/cms_request_details_#{language.downcase}.xml.gz") }
      }

      assert_difference 'CmsRequest.count', 1 do
        assert_difference 'CmsTargetLanguage.count', 1 do
          post("/websites/#{@website.id}/cms_requests.xml", params: params)
          assert_response :success
          assert_select 'info result[id]'
        end
      end

      # Simulate processing by TAS and otgs-segmenter
      tas_mock
      otgs_segmenter_mock

    end
  end

  def get_translation_requests
    params = { 'accesskey' => @website.accesskey }
    get("/websites/#{@website.id}/cms_requests", { format: :xml }, params)
    assert_response :success
  end

  def set_translation_url
    cms_request = @website.cms_requests.last
    params = {
      'accesskey' => @website.accesskey,
      'language' => 'Spanish',
      'permlink' => 'http://www.test.com'
    }
    post("/websites/#{@website.id}/cms_requests/#{cms_request.id}/update_permlink.xml", params: params)
    assert_response :success
  end

  def download_translations
    # Missing
  end

  def mark_as_complete
    # Missing
  end

  def edit_information
    # Get to home screen
    get('/client')
    assert_response :success, "Can't get client home page"

    # Test alias permissions
    login(@alias_cant_do)
    # Unauthorized Alias user should get a 404 error page
    assert_raises ActionController::RoutingError do
      get(wpml_website_url(@website))
    end
    login(@alias_cant_edit)
    get(wpml_website_url(@website))
    assert_response :success, "Alias with permissions can't see this page"
    assert_select 'input#edit_website_details', 0
    login(@client)

    # Access main project page
    get(wpml_website_url(@website))
    assert_response :success, "Can't view the website"
    assert_select 'input#edit_website_details'

    # Click in edit button
    post(edit_description_website_url(@website, format: :js), req: :show)
    assert_response :success

    # alias can't modify the descriptions
    category_id = 1
    name = 'New test name'
    description = 'Some new description here.'
    url = 'http://somenewurlhere.com'
    [@alias_cant_do, @alias_cant_edit].each do |user|
      login user
      post(edit_description_website_url(@website), params: { commit: :Save, website: { category_id: category_id,
                                                                                       name: name, description: description, url: url } })
      assert_response :redirect
      @website.reload
      assert_not_equal name, @website.name
      assert_not_equal description, @website.description
      assert_not_equal category_id, @website.category_id
      assert_not_equal url, @website.url
    end
    login @client

    # modify the descriptions
    post(edit_description_website_url(@website, format: :js), params: { commit: :Save, website: { category_id: category_id,
                                                                                                  name: name, description: description, url: url } })
    assert_response :success
    @website.reload
    assert_equal name, @website.name
    assert_equal description, @website.description
    assert_equal category_id, @website.category_id
    assert_equal url, @website.url
  end

  def invite_translators
    # Access main project page
    get(wpml_website_url(@website))
    assert_response :success, "Can't view the website"

    # The new website page no longer links to the WTO pages
    # @website.website_translation_offers.each do |wto|
    #   assert_select "a[href='#{website_website_translation_offer_path(@website, wto)}']"
    # end

    @website.website_translation_offers.each do |wto|
      # Alias can't see translator screen
      login(@alias_cant_do)
      get(website_website_translation_offer_path(@website, wto))
      assert_response :redirect, 'Alias without permissions can see this page'
      login(@alias_cant_edit)
      get(website_website_translation_offer_path(@website, wto))
      assert_response :success, "Alias with permissions can't see this page"
      login(@client)

      # Go to the pick translators screen
      get(website_website_translation_offer_path(@website, wto))
      assert_response :success
      assert assigns(:translators).include? @translator

      # Go to the invite screen
      get(new_invitation_website_website_translation_offer_url(@website, wto), but: 'Invite this guy', translator_id: @translator.id)
      assert_response :success
      assert_select 'textarea#website_translation_offer_sample_text'

      # Alias can't send the invitations
      invitation = 'Come and join'
      sample_text = 'One two three'
      [@alias_cant_do, @alias_cant_edit].each do |user|
        login user
        assert_no_difference('ActionMailer::Base.deliveries.length') do
          post(create_invitation_website_website_translation_offer_url(@website, wto), website_translation_offer: {
                 invitation: invitation, sample_text: sample_text
               }, category_id: 1, translator_id: @translator.id)
          assert_response :redirect
          assert_not_equal "You have invited #{@translator.nickname}", flash[:notice]
        end
      end
      login @client

      # Send the invitation
      assert_difference('ActionMailer::Base.deliveries.length', 1) do
        assert_difference('WebsiteTranslationContract.count', 1) do
          post(create_invitation_website_website_translation_offer_url(@website, wto), website_translation_offer: {
                 invitation: invitation, sample_text: sample_text
               }, category_id: 1, translator_id: @translator.id)
          assert_response :redirect
          assert_equal "You have invited #{@translator.nickname}", flash[:notice]
        end
      end
    end
  end

  def enable_review
    # Access main project page
    get(wpml_website_url(@website))
    assert_response :success, "Can't view the website"
    assert 'a#enable_review', 2

    # Alias can't see enable review button
    login(@alias_cant_do)
    get(wpml_website_url(@website))
    assert_response :redirect, 'Alias without permissions can see this page'
    login(@alias_cant_edit)
    get(wpml_website_url(@website))
    assert_response :success, "Alias with permissions can't see this page"
    assert 'a#enable_review', 0
    login(@client)

    # And alias also can't click on it
    @website.website_translation_offers.each do |wto|
      managed_work = wto.managed_work
      [@alias_cant_do, @alias_cant_edit].each do |user|
        login user
        post(update_status_managed_work_url(managed_work), active: 1)
        assert_response :redirect
        managed_work.reload
        assert_equal MANAGED_WORK_INACTIVE, managed_work.status
      end
    end
    login @client

    # enable review for spanish
    wto = @website.website_translation_offers.last
    managed_work = wto.managed_work
    post(update_status_managed_work_url(managed_work), active: 1)
    assert_response :success
    managed_work.reload
    assert_equal MANAGED_WORK_ACTIVE, managed_work.status
  end

  def make_bids
    # Go to home page;
    get '/translator'
    assert_response :success

    # link should be there somewhere
    @website.website_translation_contracts.each do |wtc|
      assert_select "a[href='#{website_website_translation_offer_website_translation_contract_path(@website, wtc.website_translation_offer, wtc)}']"
    end

    @website.website_translation_contracts.each do |wtc|
      # Go to contract page
      get(website_website_translation_offer_website_translation_contract_url(@website, wtc.website_translation_offer, wtc))
      assert_response :success
      assert_select "input[value='Apply for this work']"

      # create a message
      assert_difference('ActionMailer::Base.deliveries.length', 1) do
        assert_difference('wtc.reload; wtc.messages.count', 1) do
          post(create_message_website_website_translation_offer_website_translation_contract_url(@website, wtc.website_translation_offer, wtc, format: :js),
               max_idx: 1, body: 'Thanks for the invitation', for_who1: @client.id)
          assert_response :success
        end
      end

      # click on apply
      assert_difference('ActionMailer::Base.deliveries.length', 1) do
        post(update_application_status_website_website_translation_offer_website_translation_contract_url(@website, wtc.website_translation_offer, wtc),
             website_translation_contract: { amount: 11.00 }, status: 1)
        assert_response :redirect
        assert_equal 'Application updated.', flash[:notice]
      end
    end
  end

  def accept_bids
    # Access main project page
    get(wpml_website_url(@website))
    assert_response :success, "Can't view the website"

    @website.website_translation_contracts.each do |wtc|
      # Check alias access to this page
      login(@alias_cant_do)
      get(website_website_translation_offer_website_translation_contract_url(@website, wtc.website_translation_offer, wtc))
      assert_response :redirect, 'Alias without permissions can see this page'
      login(@alias_cant_edit)
      get(website_website_translation_offer_website_translation_contract_url(@website, wtc.website_translation_offer, wtc))
      assert_response :success, "Alias with permissions can't see this page"
      assert_select "input[value='Accept this application']", 0
      login(@client)

      # Go to contract page
      get(website_website_translation_offer_website_translation_contract_url(@website, wtc.website_translation_offer, wtc))
      assert_response :success
      assert_select "input[value='Accept this application']"

      # Aliases can't create messages
      [@alias_cant_do, @alias_cant_edit].each do |user|
        login user
        assert_no_difference('ActionMailer::Base.deliveries.length', 1) do
          assert_no_difference('wtc.reload; wtc.messages.count') do
            post(create_message_website_website_translation_offer_website_translation_contract_url(@website, wtc.website_translation_offer, wtc),
                 max_idx: 1, body: 'Thanks for the invitation', for_who1: @client.id)
            assert_response :redirect
          end
        end
      end
      login @client

      # create a message
      assert_difference('ActionMailer::Base.deliveries.length', 1) do
        assert_difference('wtc.reload; wtc.messages.count', 1) do
          post(create_message_website_website_translation_offer_website_translation_contract_url(@website, wtc.website_translation_offer, wtc, format: :js),
               max_idx: 1, body: 'Thanks for the bid', for_who1: @translator.id)
          assert_response :success
        end
      end

      # Aliases can't accept the application
      [@alias_cant_do, @alias_cant_edit].each do |user|
        login user
        assert_no_difference('ActionMailer::Base.deliveries.length') do
          post(update_application_status_website_website_translation_offer_website_translation_contract_url(@website, wtc.website_translation_offer, wtc),
               status: 2)
          assert_response :redirect
          assert_not_equal 2, wtc.status
        end
      end
      login @client

      # Accept the applications
      post(update_application_status_website_website_translation_offer_website_translation_contract_url(@website, wtc.website_translation_offer, wtc),
           status: 2)
      assert_response :redirect
      wtc.reload
      assert_equal 2, wtc.status
    end
  end

  def deposit_money
    get(new_wpml_website_payment_path(@website))
    assert_response :success

    [@alias_cant_edit, @alias_cant_pay].each do |user|
      login user
      get(new_wpml_website_payment_path(@website))
      assert_response :success
      # Ensure there is not a "pay" button
      assert_select '#pay', 0
    end

    login @client
    get(new_wpml_website_payment_path(@website))
    assert_response :success
    # Ensure there is a "pay" button
    assert_select '#pay'
  end

  def do_translations
    # Can't implement from here, missing too hard TAS stub.
  end
end
