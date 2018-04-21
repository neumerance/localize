module UtilsHelper

  def login_as(user)
    session = FactoryGirl.create(:user_session, user_id: user.id).session_num
    request.session[:session_num] = session
  end

  def request_spec_login(email, password)
    post '/login/login', params: { email: email, password: password, commit: 'Login' }
  end

  def auth_token(user)
    post(api_authenticate_path, params: { email: user.email, password: user.password })
    json = ActiveSupport::JSON.decode(response.body)
    json['auth_token']
  end

  def captcha_code
    @captcha_image = CaptchaImage.new(content_type: 'image/jpeg', filename: 'captcha.jpg')
    @captcha_image.generate_image
    [@captcha_image.code, @captcha_image.id]
  end

  def randomize_case(str)
    new_str = ''
    str.each_char do |c|
      new_str << if rand(2) == 1
                   c.upcase
                 else
                   c.downcase
                 end
    end
    new_str
  end

  def randomize_empty_spaces(str)
    new_str = ''
    rand(5).times do
      new_str << ' '
    end
    new_str << str
    rand(5).times do
      new_str << ' '
    end
    new_str
  end

end
