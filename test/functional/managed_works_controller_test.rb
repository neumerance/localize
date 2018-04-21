require File.dirname(__FILE__) + '/../test_helper'
require 'managed_works_controller'

# Re-raise errors caught by the controller.
class ManagedWorksController
  def rescue_action(e)
    raise e
  end
end

class ManagedWorksControllerTest < ActionController::TestCase
  fixtures :users, :user_sessions, :managed_works

  def test_be_reviewer
    orit = users(:orit)
    orit_session = user_sessions(:orit).session_num

    managed_work = managed_works(:text_resource_iphone_spanish)

    assert_nil managed_work.translator

    assert_equal false, managed_work.translator_can_apply_to_review(orit)

    post :be_reviewer, params: { controller: 'managed_work', id: managed_work.id, session: orit_session }
    assert_response :redirect

    msg = assigns(:msg)
    assert_equal 'You cannot be the reviewer for this job.', msg

    managed_work.reload
    assert_nil managed_work.translator

    # for guy, it should work

    guy = users(:guy)
    guy_session = user_sessions(:guy).session_num

    guy.level = EXPERT_TRANSLATOR
    guy.save

    assert_equal true, managed_work.translator_can_apply_to_review(guy)

    post :be_reviewer, params: { id: managed_work.id, session: guy_session }
    assert_response :redirect

    # msg = assigns(:msg)
    # assert_nil msg

    managed_work.reload
    assert_equal guy, managed_work.translator

  end
end
