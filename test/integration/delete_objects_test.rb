require "#{File.dirname(__FILE__)}/../test_helper"

class DeleteObjectsTest < ActionDispatch::IntegrationTest
  fixtures :users, :money_accounts, :languages, :currencies, :identity_verifications, :projects, :revisions

  def test_delete_existing
    UserSession.delete_all
    Bid.delete_all

    # log in as a client
    client = users(:amir)
    project = setup_full_project(client, 'To be deleted')
    project_id = project.id
    session = login(client)

    # log in as a client
    translator = users(:orit)
    xsession = login(translator)

    revision = project.revisions[-1]
    revision_id = revision.id

    # release this revision
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_release_status),
                     session: session, project_id: project.id, id: revision.id, req: 'show')
    assert_response :success
    assert_nil assigns(:warnings)

    # create a chat in this revision
    chat_id = create_chat(xsession, project.id, revision.id)
    chat = Chat.find(chat_id)

    # the revision canot be deleted now
    post(url_for(controller: :revisions, action: :delete, project_id: project.id, id: revision.id, format: 'xml'),
         session: session, _method: 'DELETE')
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute('Revision cannot be deleted now', xml.root.elements['result'], 'message')
    assert Revision.where('id=?', revision_id).first

    # the project too, cannot be deleted right now
    post(url_for(controller: :projects, action: :delete, id: project.id, format: 'xml'),
         session: session, _method: 'DELETE')
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute('Project cannot be deleted now', xml.root.elements['result'], 'message')
    assert Project.where('id=?', project_id).first

    # hide this revision
    xml_http_request(:post, url_for(controller: :revisions, action: :edit_release_status),
                     session: session, project_id: project.id, id: revision.id, req: 'show')
    assert_response :success
    assert_nil assigns(:warnings)

    # now, it can be deleted
    post(url_for(controller: :revisions, action: :delete, project_id: project.id, id: revision.id, format: 'xml'),
         session: session, _method: 'DELETE')
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute('Revision deleted', xml.root.elements['result'], 'message')
    assert_nil Revision.where('id=?', revision_id).first
    assert_nil Project.where('id=?', project_id).first

  end
end
