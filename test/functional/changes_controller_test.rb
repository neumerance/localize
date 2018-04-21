require File.dirname(__FILE__) + '/../test_helper'
require 'changes_controller'

# Re-raise errors caught by the controller.
class ChangesController
  def rescue_action(e)
    raise e
  end
end

class ChangesControllerTest < ActionController::TestCase
  fixtures :users

  def test_changnum
    # login normally
    user_session = UserSession.create!(session_num: 'SESSION1',
                                       login_time: Time.now,
                                       user_id: users(:amir).id)
    get :changenum, params: { format: 'xml', session: user_session.session_num }
    assert_response :success
    assert_nil assigns['err_code']

    # check what happens if there's a timeout
    user_session.update_attributes(login_time: Time.now - (SESSION_TIMEOUT + 1))
    get :changenum, params: { format: 'xml', session: user_session.session_num }
    assert_response :success
    assert_equal NOT_LOGGED_IN_ERROR, assigns['err_code']

    # check what happens after logout (session doesn't exist)
    user_session.destroy
    get :changenum, params: { format: 'xml', session: user_session.session_num }
    assert_response :success
    assert_equal NOT_LOGGED_IN_ERROR, assigns['err_code']
  end
end
