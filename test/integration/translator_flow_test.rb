require "#{File.dirname(__FILE__)}/../test_helper"

class TranslatorFlowTest < ActionDispatch::IntegrationTest
  fixtures :users, :money_accounts, :languages, :currencies, :translator_languages, :identity_verifications

  def test_translator_flow

    @real_revision = create_real_project
    # create a practice projece
    practiceuser = users(:practiceuser)

    # log in as a the practice user (which creates the practice projects)
    project = setup_full_project(practiceuser, 'Practice project')
    revision = project.revisions[0]

    # log in as a translator
    translator = users(:newbi)
    assert_equal USER_STATUS_REGISTERED, translator.userstatus
    xsession = login(translator)
    xchangenum = get_track_num(xsession)

    osession = login(translator)
    changenum = get_track_num(osession)

    # try to bid on the real project, it should fail
    post url_for(controller: :chats, action: :create), params: { project_id: @real_revision.project_id, revision_id: @real_revision.id }
    assert_response :redirect
    assert flash[:notice]
    chat = translator.chats.where('revision_id=?', @real_revision.id).first
    assert_nil chat
    @real_revision.reload

    # request practice project
    get(url_for(controller: :users, action: :request_practice_project))
    assert_response :success
    from_languages = assigns(:from_languages)
    to_languages = assigns(:to_languages)
    assert_equal 1, from_languages.length
    assert_equal translator.to_languages.length - 1, to_languages.length

    # setup the practice project
    proj_count = Project.count
    rev_count = Revision.count

    args = { source_language_id: from_languages.values[0] }
    to_languages.each { |lang| args["target_language[#{lang.id}]"] = 1 }

    post url_for(controller: :users, action: :setup_practice_project), params: args
    assert_response :success

    # check that the other session for this translator noticed the change
    changenum = assert_track_changes(osession, changenum, "Changenum didn't increment practice project was created")
    xchangenum = assert_track_changes(xsession, xchangenum, "Changenum didn't increment practice project was created")

    # check that the practice project is set up correctly
    assert_equal proj_count + 1, Project.count
    assert_equal rev_count + 1, Revision.count

    project = Project.all.to_a[-1]
    assert project
    revision = project.revisions[0]
    assert revision

    assert_equal 1, revision.released
    assert_equal to_languages.length, revision.revision_languages.count
    assert_equal 0, revision.open_to_bids

    bids_to_finalize = []
    # check that there's a zero amount bid, and it's been accepted
    revision.revision_languages.each do |revision_language|
      assert_equal 1, revision_language.bids.count
      bid = revision_language.bids[0]
      assert_equal 0, bid.amount
      assert_equal BID_ACCEPTED, bid.status
      bids_to_finalize << bid
    end

    # translator completes the work
    translator_completes_work(xsession, revision.chats[0])

    revision.revision_languages.each do |revision_language|
      bid = revision_language.bids[0]
      bid.reload
      assert_equal BID_DECLARED_DONE, bid.status
    end

    # client accepts the work as completed
    democlient = users(:democlient)
    session = login(democlient)
    client_finalizes_bids(session, bids_to_finalize)

    # translator's status updated to QUALIFIED
    translator.reload
    assert_equal USER_STATUS_QUALIFIED, translator.userstatus

    # try to bid on the real project, now it should work
    logout(xsession)
    xsession = login(translator)

    post url_for(controller: :chats, action: :create), params: { project_id: @real_revision.project_id, revision_id: @real_revision.id }
    assert_response :redirect
    assert_nil flash[:notice]
    chat = translator.chats.where('revision_id=?', @real_revision.id).first
    assert chat
  end

  def create_real_project
    # setup a real project, to see if the translator can start a chat and bid on it
    client = users(:amir)

    project = setup_full_project(client, 'Real project')
    revision = project.revisions[0]

    session = login(client)

    # release this revision
    post url_for(controller: :revisions, action: :edit_release_status, project_id: project.id, id: revision.id),
         params: { session: session, req: 'show' },
         xhr: true

    assert_response :success
    assert_nil assigns(:warnings)

    revision
  end

end
