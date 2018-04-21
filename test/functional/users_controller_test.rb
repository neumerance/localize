require File.dirname(__FILE__) + '/../test_helper'
require 'users_controller'

# Re-raise errors caught by the controller.
class UsersController
  def rescue_action(e)
    raise e
  end
end

class UsersControllerTest < ActionController::TestCase
  fixtures :user_sessions

  def test_supporter_should_get_index
    user_session = user_sessions(:admin)
    get :index, params: { session: user_session.session_num }
    assert_response :success
    assert assigns(:users_page)
  end

  def test_normal_user_shouldnt_get_index
    user_session = user_sessions(:amir)
    get :index, params: { session: user_session.session_num }
    assert_response :redirect
    assert_nil assigns(:users_page)
  end

  def test_should_get_new
    get(:new, utype: 'Client')
    assert_equal 'NormalUser', assigns(:auser)[:type]
    assert_response :success

    get(:new, utype: 'Translator')
    assert_equal 'NormalUser', assigns(:auser)[:type]
    assert_response :success
  end

  def test_list_translation_languages
    user_session = user_sessions(:admin)
    get :list_translation_languages, params: { session: user_session.session_num }
    assert_response :success

    post :update_translation_language_results,
         params: {
           source_lang_id: 1,
           target_lang_id: 4,
           session: user_session.session_num,
           format: :js
         }

    assert_response :success

    post :update_translation_language_results,
         params: {
           source_lang_id: 4,
           target_lang_id: 1,
           include_unqualified: 1,
           session: user_session.session_num,
           format: :js
         }

    assert_response :success
  end

  def test_should_create_user
    # test correct Client insertion
    old_count = User.count

    captcha_image = CaptchaImage.new(content_type: 'image/jpeg', filename: 'captcha.jpg')
    captcha_image.generate_image
    old_captcha_count = CaptchaImage.count

    post :create,
         params: {
           utype: 'Client',
           auser: { nickname: 'juli', fname: 'Fifi', lname: 'Bonjour', email: 'fifi@xdot.com', password: 'fifi' },
           password_check: 'fifi',
           captcha_id: captcha_image.id,
           code: captcha_image.code,
           accept_agreement: 1,
           submit: 'Submit'
         }

    assert_response :success
    assert_equal old_count + 1, User.count
    assert_equal CaptchaImage.count, old_captcha_count
    user = User.where('email=?', 'fifi@xdot.com').first
    assert user
    assert_equal USER_STATUS_NEW, user.userstatus
    assert_equal 'Client', user[:type]
    assert user.signup_date
    assert((user.signup_date.to_i - Time.now.to_i) < 5)

    # test correct Translator insertion
    old_count = User.count

    captcha_image = CaptchaImage.new(content_type: 'image/jpeg', filename: 'captcha.jpg')
    captcha_image.generate_image
    old_captcha_count = CaptchaImage.count

    post :create,
         params: {
           utype: 'Translator',
           auser: { nickname: 'bob', fname: 'Roro', lname: 'Bonjour', email: 'roro@dot.com', password: 'roro' },
           password_check: 'roro',
           captcha_id: captcha_image.id,
           code: captcha_image.code,
           accept_agreement: 1,
           submit: 'Submit'
         }

    assert_response :success
    assert_equal old_count + 1, User.count
    assert_equal CaptchaImage.count, old_captcha_count
    user = User.where('email=?', 'roro@dot.com').first
    assert user
    assert_equal USER_STATUS_NEW, user.userstatus
    assert_equal 'Translator', user[:type]
    assert_equal NEWSLETTER_NOTIFICATION | DAILY_RELEVANT_PROJECTS_NOTIFICATION, user.notifications
    assert_equal NEWSLETTER_NOTIFICATION | DAILY_RELEVANT_PROJECTS_NOTIFICATION, NEWSLETTER_NOTIFICATION +
                                                                                 DAILY_RELEVANT_PROJECTS_NOTIFICATION

    # try a bad validation code
    get :validate, params: { id: user.id, signature: user.signature + 'x' }
    assert_response :redirect
    user.reload
    assert_equal USER_STATUS_NEW, user.userstatus

    # complete the registration by validating the translator's email
    get :validate, params: { id: user.id, signature: user.signature }
    assert_response :redirect
    user.reload
    assert_equal USER_STATUS_REGISTERED, user.userstatus

    # test un-accepted user agreement
    old_count = User.count
    post :create,
         params: {
           utype: 'Translator',
           auser: { nickname: 'juli', fname: 'Fifi', lname: 'Bonjour', email: 'fifi@xdot.com', password: 'fifi' },
           password_check: 'fifi',
           captcha_id: captcha_image.id,
           code: captcha_image.code,
           submit: 'Submit'
         }
    assert_response :success
    assert_equal old_count, User.count
    assert assigns['user_agreement_not_accepted']

    # test bad captcha code
    old_count = User.count

    captcha_image = CaptchaImage.new(content_type: 'image/jpeg', filename: 'captcha.jpg')
    captcha_image.generate_image
    old_captcha_count = CaptchaImage.count

    post :create,
         params: {
           utype: 'Client',
           auser: { fname: 'Fifi', lname: 'Bonjour', email: 'fifi@dot.com', password: 'fifi' },
           password_check: 'fifi',
           captcha_id: captcha_image.id,
           code: captcha_image.code + 'x',
           accept_agreement: 1,
           submit: 'Submit'
         }
    assert_response :success
    assert_equal old_count, User.count
    assert_equal CaptchaImage.count, old_captcha_count

    # test bad captcha ID
    old_count = User.count

    captcha_image = CaptchaImage.new(content_type: 'image/jpeg', filename: 'captcha.jpg')
    captcha_image.generate_image
    old_captcha_count = CaptchaImage.count

    post :create,
         params: {
           utype: 'Client',
           auser: { fname: 'Fifi', lname: 'Bonjour', email: 'fifi@dot.com', password: 'fifi' },
           password_check: 'fifi',
           captcha_id: captcha_image.id + 1,
           code: captcha_image.code,
           accept_agreement: 1,
           submit: 'Submit'
         }

    assert_response :success
    assert_equal old_count, User.count
    assert_equal CaptchaImage.count, old_captcha_count
    captcha_image.destroy

    # test bad user insertion - mismatched password
    old_count = User.count
    post :create,
         params: {
           utype: 'Client',
           auser: { fname: 'Gifi', lname: 'Bonjour', email: 'gifi@dot.com', password: 'fifi' },
           password_check: 'fifi_',
           submit: 'Submit'
         }
    assert_equal old_count, User.count
    assert_response :success

    # test bad user insertion - non existing type
    captcha_image = CaptchaImage.new(content_type: 'image/jpeg', filename: 'captcha.jpg')
    captcha_image.generate_image
    old_captcha_count = CaptchaImage.count

    old_count = User.count
    post :create,
         params: {
           utype: 'Zombi',
           auser: { fname: 'Fifi', lname: 'Bonjour', email: 'zombi@dot.com', password: 'fifi' },
           password_check: 'fifi',
           captcha_id: captcha_image.id,
           code: captcha_image.code,
           submit: 'Submit'
         }
    assert_equal old_count, User.count
    assert_response :success
    # assert_redirected_to user_path(assigns(:user))
  end

  def test_should_show_user
    user_session = user_sessions(:amir)
    # show the page of this user
    get :show, params: { session: user_session.session_num, id: user_session.user_id }
    assert_response :success
    assert assigns(:canedit), 'User must be able to edit for himself'

    # show the page of another user
    get :show, params: { session: user_session.session_num, id: user_session.user_id + 1 }
    assert_response :success
    assert !assigns(:canedit), 'User must not be able to edit for others'
  end

  def test_should_get_edit
    # normal users cannot
    user_session = user_sessions(:amir)
    normaluser_id = user_session.user_id
    get :edit, params: { session: user_session.session_num, id: user_session.user_id }
    assert_response :redirect

    # supporters can use this
    user_session = user_sessions(:admin)
    get :edit, params: { session: user_session.session_num, id: normaluser_id }
    assert_response :success

  end

  def test_should_update_user
    # normal users cannot
    user_session = user_sessions(:amir)
    normaluser_id = user_session.user_id
    put :update, params: { session: user_session.session_num, id: user_session.user_id }
    assert_response :redirect

    # supporters can use this
    user_session = user_sessions(:admin)
    put :update, params: {
      session: user_session.session_num, id: normaluser_id,
      auser: { fname: 'George', email: 'xxx@yyy.com' }
    }
  end

  def test_close_account
    user_session = user_sessions(:amir)
    user = user_session.user
    user.money_accounts.first.update_attribute :balance, 0
    post :close_account, params: { session: user_session.session_num, id: user.id, verify_password: get_user_test_password(user) }
    assert_response :success
    user.reload
    assert_equal USER_STATUS_CLOSED, user.userstatus
  end

  def test_welcome_emails
    sources = [['http://www.icanlocalize.com/site/services/website-translation/drupal-translation/', 'drupal'],
               ['CMS Drupal', 'drupal'],
               ['http://www.icanlocalize.com/site/services/website-translation/wordpress-translation/', 'wordpress'],
               ['CMS WordPress', 'wordpress']]

    idx = 1
    sources.each do |source|
      user = Client.create!(fname: 'test', lname: 'user', nickname: "testuser#{idx}",
                            email: "testuser#{idx}@malinator.com", password: 'something', userstatus: USER_STATUS_NEW,
                            source: source[0])

      # complete the registration by validating the translator's email
      get :validate, params: { id: user.id, signature: user.signature }
      assert_response :redirect
      user.reload
      assert_equal USER_STATUS_REGISTERED, user.userstatus

      assert assigns(:sent_type)
      assert_equal source[1], assigns(:sent_type)

      idx += 1
    end
  end

end
