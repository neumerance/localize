require "#{File.dirname(__FILE__)}/../test_helper"

class AffiliatesTest < ActionDispatch::IntegrationTest
  fixtures :users, :languages, :captcha_backgrounds

  def test_bad_page
    get(url_for(controller: :my, action: :invite, id: 1000))
    assert_response :redirect

    get(url_for(controller: :my, action: :invite, id: 'problem'))
    assert_response :redirect
  end

  def test_success_of_signup
    get(url_for(controller: :users, action: :new))
    assert_response :success
  end

  def test_sign_up

    idx = 1
    [users(:amir), users(:shark)].each do |affiliate|

      assert_nil affiliate.invitation

      # before setting up the affiliate data
      get(url_for(controller: :my, action: :invite, id: affiliate.id))
      assert_response :redirect

      asession = login(affiliate)

      # get the main page for affiliate actions
      get(url_for(controller: :my, action: :index))
      assert_response :success
      assert assigns('invitation_html')

      get(url_for(controller: :my, action: :edit))
      assert_response :success

      name = 'hello there'
      message = 'something smart'
      post(url_for(controller: :my, action: :update), invitation: { name: name, message: message, active: 0 })
      assert_response :success

      name = 'hello there'
      message = 'something smart'
      post(url_for(controller: :my, action: :update), invitation: { name: name, message: message, active: 1 })
      assert_response :redirect

      affiliate.reload
      assert affiliate.invitation

      logout(asession)

      # now, once the invitation exists and is enabled, invitees can sign up
      get(url_for(controller: :my, action: :invite, id: affiliate.id))
      assert_response :success
      assert_equal affiliate.id, session[AFFILIATE_CODE_COOKIE]

      get(url_for(controller: :users, action: :new))
      assert_response :success

      old_count = User.count

      captcha_image = CaptchaImage.new(content_type: 'image/jpeg', filename: 'captcha.jpg')
      captcha_image.generate_image
      old_captcha_count = CaptchaImage.count

      idxs = idx.to_s

      post(url_for(controller: :users, action: :create), utype: 'Client',
                                                         auser: { nickname: 'juli' + idxs, fname: 'Fifi', lname: 'Bonjour',
                                                                  email: 'fifi' + idxs + '@xdot.com', password: 'fifi' },
                                                         password_check: 'fifi',
                                                         captcha_id: captcha_image.id,
                                                         code: captcha_image.code,
                                                         accept_agreement: 1,
                                                         submit: 'Submit')
      assert_response :success
      assert_equal old_count + 1, User.count
      assert_equal CaptchaImage.count, old_captcha_count
      user = User.where('email=?', 'fifi' + idxs + '@xdot.com').first
      assert user

      assert_equal affiliate.id, user.affiliate_id

      assert_equal USER_STATUS_NEW, user.userstatus
      assert_equal 'Client', user[:type]
      assert user.signup_date
      assert((user.signup_date.to_i - Time.now.to_i) < 5)

      affiliate.reload
      assert_equal 1, affiliate.invitees.length

      idx += 1

    end
  end

end
