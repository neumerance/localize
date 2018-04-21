require File.dirname(__FILE__) + '/../test_helper'
require 'projects_controller'

# Re-raise errors caught by the controller.
class ProjectsController
  def rescue_action(e)
    raise e
  end
end

class ProjectsControllerTest < ActionController::TestCase
  fixtures :users
  fixtures :user_sessions
  fixtures :projects

  def test_index
    user_session = user_sessions(:amir)
    for format in %w(xml html)
      get :index, params: { session: user_session.session_num, format: format }
      assert_response :success
      next unless format == 'xml'
      xml = get_xml_tree(@response.body)
      assert_element_text('logged in', xml.elements['info/status'])
      assert xml.root.elements['projects']
    end
  end

  def test_create
    # user_session = user_sessions(:amir)
    # create for the first time, see that the project is created OK
    # old_count = Project.count
    # project_name = Faker::App.name
    # post :create, params: { session: user_session.session_num, name: project_name, format: 'xml' }
    # assert_response :success
    # assert_equal old_count + 1, Project.count
    # xml = get_xml_tree(@response.body)
    # assert_element_text('logged in', xml.elements['info/status'])
    # assert_element_attribute('Project created', xml.root.elements['result'], 'message')
    # id = get_element_attribute(xml.root.elements['result'], 'id')
    # assert_not_nil id
    # project = Project.find(id)
    # assert_equal user_session.user_id, project.client_id
    #
    # # create a second time, get a result that it already exists
    # post :create, params: { session: user_session.session_num, name: project_name, format: 'xml' }
    # assert_response :success
    # project = assigns(:project)
    # assert_equal project.errors.count, 1 # error count should be 1 for project cant be save and project name is unique
    # xml = get_xml_tree(@response.body)
    # assert_element_attribute(PROJECT_CANNOT_BE_SAVED_ERROR.to_s, xml.elements['info/status'], 'err_code')
    #
    # # check that translators cannot create projects
    # user_session = user_sessions(:orit)
    #
    # post :create, params: { session: user_session.session_num, name: Faker::App.name, format: 'xml' }
    # assert_response :success
    # assert_equal old_count + 1, Project.count
    # # puts @response.body
    # xml = get_xml_tree(@response.body)
    # assert_element_attribute(ONLY_CLIENT_CAN_CREATE_PROJECT_ERROR.to_s, xml.elements['info/status'], 'err_code')

  end

  def test_show
    user_session = user_sessions(:amir)

    # user checks his own project
    project = projects(:PB)
    get :show, params: { session: user_session.session_num, id: project.id, format: 'xml' }
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_text('logged in', xml.elements['info/status'])
    assert_element_attribute(project.name, xml.root.elements['project'], 'name')

    # user checks another's project
    project = projects(:SP)
    get :show, params: { session: user_session.session_num, id: project.id, format: 'xml' }
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_text("Access forbidden - not your project (or you don't have permission for that)",
                        xml.elements['info/status'])
    assert_nil xml.root.elements['project']
  end
end
