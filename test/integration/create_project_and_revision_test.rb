require 'zlib'
require "#{File.dirname(__FILE__)}/../test_helper"

class CreateProjectAndRevisionTest < ActionDispatch::IntegrationTest
  fixtures :users, :money_accounts, :languages, :currencies, :translator_languages, :identity_verifications, :projects

  # TODO: fix XmlStreamListener and recheck
  skip def test_project_upload_and_setup
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
    #	{:session=>session, :id=>project_id, :format=>'xml' } )
    # assert_response :success

    changenum = get_track_num(session)

    # create a new revision
    revision_id = create_revision(session, project_id, 'Created by test')
    revision = Revision.find(revision_id)
    changenum = assert_track_changes(session, changenum, "Changenum didn't increment after revision was created")

    display_stats('After project creation', project, revision, session)

    # ---------------- upload support files and a new version ------------------------
    support_file_id = create_support_file(session, project_id, 'sample/support_files/styles.css.gz')

    #    upload_sample_file(fname, produced_fname, support_file_id, revision_id)

    # try to upload a bad file, see that the upload fails
    upload_sample_file('PB.xml', 'produced_bad.xml.gz', support_file_id, revision_id + 1)

    # create a project file that includes the correct support file ID
    upload_sample_file('PB.xml', 'produced.xml.gz', support_file_id, revision_id)

    # create a project file that includes the correct support file ID
    fsize = upload_sample_file('multiple_languages.xml', 'produced_multiple_lang.xml.gz', support_file_id, revision_id)

    # upload a bad project file (upload version)
    version_id = create_version(session, project_id, revision_id, 'sample/Initial/produced_bad.xml.gz')
    display_stats('After first upload', project, revision, session)

    # get the uploaded version XML and see that all information is there
    get(url_for(controller: :versions, action: :show, project_id: project.id, revision_id: revision.id, id: version_id, format: 'xml'),
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
    display_stats('After second upload', project, revision, session)
    assert_equal 1, revision.versions.reload.count

    # update this project file (upload version)
    update_version(session, project_id, revision_id, version_id, 'sample/Initial/produced.xml.gz')
    display_stats('After first update', project, revision, session)

    # update should be possible
    update_version(session, project_id, revision_id, version_id, 'sample/Initial/produced_multiple_lang.xml.gz')
    display_stats('After 2nd update', project, revision, session)

    delete_temporaty_files

    # Important Note:
    #		On original ICL update was updating the version, but we found a bug on TA, it takes the latest version by ID
    #		If a translator already uploaded a version there is no way from a client to update the document.
    #		So at some point we changed the VersionsController#update to create a new version instead of update, check 740cc978
    #
    # 	This test was originally expecting only one version to exists, but now each update creates a new version instead
    #		of update it.
    #
    #		While fixing this tests I decided that there is no sense in create a new version as, in order to update the
    #	  project shouldn't be released, so there is no way that a translated versions exists.

    # get the uploaded version XML and see that all information is there
    get(
      url_for(
        controller: :versions,
        action: :show,
        project_id: project.id,
        revision_id: revision.id,
        id: version_id,
        format: 'xml'
      ),
      session: session
    )

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

    xml_http_request(:post, url_for(controller: :revisions, action: :edit_description, project_id: project_id, id: revision_id),
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
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_conditions, project_id: project_id, id: revision_id),
                     session: session, req: 'save', revision: { max_bid: max_bid, bidding_duration: bidding_duration, project_completion_duration: project_completion_duration, word_count: 1 })
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
    # {"commit"=>"Save", "project_id"=>"8", "language"=>{"2"=>"1", "3"=>"1", "4"=>"1"}, "action"=>"edit_languages", "id"=>"6", "controller"=>"revisions", "req"=>"save"}

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

    check_client_pages(client, session)

  end

  def test_revision_locking
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
    # return
    get(url_for(controller: :revisions, action: :show, project_id: project.id, id: revision.id, format: 'xml'), session: session)
    assert_response :success
    xml = get_xml_tree(@response.body)
    contents = xml.root.elements['revision']
    stats = contents.elements['stats']
    assert stats
    Rails.logger.info "\n\n#{message}"
    Rails.logger.info "\n\nVersions Count: #{revision.versions.reload.count}"
    Rails.logger.info stats
  end

  def delete_temporaty_files
    @files_to_delete.each { |file| File.delete(file) }
  end

  SAMPLE_INITIAL_FILES_PATH = "#{File.expand_path(Rails.root)}/test/fixtures/sample/Initial/".freeze

  def upload_sample_file(fname, produced_fname, support_file_id, revision_id)
    f = File.open(File.join(SAMPLE_INITIAL_FILES_PATH, fname), 'rb')
    txt = f.read
    f.close

    txt = txt.gsub('$SUPPORT_FILE_ID', String(support_file_id))
    txt = txt.gsub('$REV_ID', String(revision_id))

    fullpath = File.join(SAMPLE_INITIAL_FILES_PATH, produced_fname)
    Zlib::GzipWriter.open(fullpath) { |gz| gz.write(txt) }

    @files_to_delete ||= []
    @files_to_delete << fullpath

    File.size(fullpath)
  end
end
