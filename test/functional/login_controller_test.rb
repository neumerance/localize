require File.dirname(__FILE__) + '/../test_helper'
require 'login_controller'
require 'minitest/unit'

# Re-raise errors caught by the controller.
class LoginController
  def rescue_action(e)
    raise e
  end
end

class LoginControllerTest < ActionController::TestCase
  fixtures :users, :websites

  # *****************************************************************************
  # This function pull some user information from the users.yml file and make a
  # request to the login action, and with that determine first if variable "user"
  # is not nil, second if the password from de database is equal the the sent
  # password, third if variable "pw_ok" to check again the passwords, fourth check
  # if the variable status is equal to "loged in" which means everything it's ok
  # and finally check if the final response is redirect to another page and check
  # the session and..\..\app\controllers\login_controller.rb id of the user.
  # *****************************************************************************
  def test_correct_login

    # Request the login action with a 'translator' user information
    [nil, 1].each do |long_life|
      test_users = [users(:amir), users(:orit), users(:guy)]
      for user in test_users
        user.update_attributes(last_login: nil)
        post :login, params: {
          action: :login,
          email: user.email,
          password: get_user_test_password(user),
          usertype: user[:type],
          long_life: long_life
        }

        assert_response :redirect

        user_session = UserSession.all.to_a[-1]
        assert_equal long_life, user_session.long_life

        assert_not_nil assigns['user']
        assert_equal true, (BCrypt::Password.new(assigns['user'].hash_password) == get_user_test_password(user))
        assert_not_equal false, assigns['pw_ok']
        assert_not_nil assigns['session_num']
        assert_equal 'logged in', assigns['status']

        user.reload
        assert_not_nil user.last_login
      end
    end

  end

  def test_login_with_accesskey

    # Request the login action with a 'translator' user information
    test_users = [[users(:orit), false], [users(:amir), true], [users(:guy), false]]
    website = websites(:amir_drupal_rpc)

    for user_str in test_users
      user = user_str[0]
      expected = user_str[1]

      UserSession.delete_all

      user.update_attributes(last_login: nil)
      post :login, params: {
        action: :login,
        email: user.email,
        wid: website.id,
        accesskey: website.accesskey,
        usertype: user[:type],
        format: 'xml'
      }

      assert_response :success

      user_session = UserSession.all.to_a[-1]

      xml = get_xml_tree(@response.body)

      session = xml.root.elements['session_num']

      if expected
        assert session

        assert_not_nil assigns['user']
        assert_equal true, (BCrypt::Password.new(assigns['user'].hash_password) == get_user_test_password(user))
        assert_not_equal false, assigns['pw_ok']
        assert_not_nil assigns['session_num']
        assert_equal 'logged in', assigns['status']

        user.reload
        assert_not_nil user.last_login
      else
        assert_nil session
      end
    end

  end

  # *****************************************************************************
  # Try to login using a wrong password.
  # *****************************************************************************

  def test_login_bad_password
    # Request the login action with fake password
    user = users(:amir)
    get :login, params: {
      email: user.email,
      password: get_user_test_password(user) + '_',
      usertype: user[:type]
    }

    assert_not_equal true, assigns['pw_ok']
    assert_nil assigns['user']
    assert_equal nil, assigns['@session_num']
  end

  # *****************************************************************************
  # Try to login using no user.
  # *****************************************************************************
  def test_login_non_existing_user
    user = users(:amir)
    get :login, params: {
      email: user.email + '_',
      password: get_user_test_password(user),
      usertype: user[:type]
    }

    assert_nil assigns['user']
    assert_not_equal true, assigns['pw_ok']
    assert_equal nil, assigns['@session_num']
  end

  # *****************************************************************************
  # Log in a user and then test the logout action
  # *****************************************************************************
  def test_logout_with_logging_user

    # Login a test user
    user = users(:amir)
    for fmt in %w(html xml)
      get :login, params: {
        email: user.email,
        password: get_user_test_password(user),
        usertype: user[:type]
      }

      # test if user was really logged in
      assert_equal 'logged in', assigns['status']

      # Request action logout
      get :logout, format: fmt

      assert_nil assigns['@user_session']
      assert_equal 'Logged out', assigns['status']
      assert_response :success
    end
  end

  # *****************************************************************************
  # Try to logout but using no user
  # *****************************************************************************
  def test_logout_without_logging_user

    for fmt in %w(html xml)
      get :logout, params: { format: fmt }

      assert_nil assigns['@user_session']
      if fmt == 'html'
        assert_response :redirect
        assert_nil assigns['err_code']
      else
        assert_response :success
        assert_equal NOT_LOGGED_IN_ERROR, assigns['err_code']
      end
    end
  end

  def test_send_password
    user = users(:amir)
    deleted_user = users(:deleted)
    email_count = ActionMailer::Base.deliveries.length

    post :send_password, params: { email: user.email + 'x' }
    assert_response :success
    assert_equal email_count, ActionMailer::Base.deliveries.length

    post :send_password, params: { email: deleted_user.email }
    assert_response :success
    assert_equal email_count, ActionMailer::Base.deliveries.length

    post :send_password, params: { email: user.email }
    assert_response :success
    assert_equal email_count + 1, ActionMailer::Base.deliveries.length
  end
end
