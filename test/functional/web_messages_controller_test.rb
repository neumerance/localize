require File.dirname(__FILE__) + '/../test_helper'
require 'web_messages_controller'

# Re-raise errors caught by the controller.
class WebMessagesController
  def rescue_action(e)
    raise e
  end
end

class WebMessagesControllerTest < ActionController::TestCase
  fixtures :user_sessions

  def test_flag_as_complex

    session = user_sessions(:orit)

    # flag first time is ok
    get :flag_as_complex, params: { session: session.session_num, id: 3 }
    assert_response :success
    assert_nil assigns['error']

    # flag a second time generates an error
    get :flag_as_complex, params: { session: session.session_num, id: 3 }
    assert_response :success
    assert_not_nil assigns['error']
  end

  def test_should_not_allow_two_translators_get_same_job
    t1 = user_sessions(:orit)
    t2 = user_sessions(:guy)

    get :hold_for_translation, params: { session: t1.session_num, id: 3 }
    assert_response :success
    assert_equal MESSAGE_HELD_FOR_TRANSLATION, assigns['err_code']

    get :hold_for_translation, params: { session: t2.session_num, id: 3 }
    assert_response :success
    assert_not_equal MESSAGE_HELD_FOR_TRANSLATION, assigns['err_code']
  end

  def test_should_not_allow_two_translators_get_same_job_for_review
    t1 = user_sessions(:orit)
    t2 = user_sessions(:guy)

    get :hold_for_review, params: { session: t1.session_num, id: 5 }
    assert_response :redirect
    assert_nil flash[:notice]

    get :hold_for_review, params: { session: t2.session_num, id: 5 }
    assert_response :redirect
    assert_not_nil flash[:notice]
  end
end
