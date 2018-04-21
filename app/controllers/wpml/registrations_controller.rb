class Wpml::RegistrationsController < Wpml::BaseWpmlController
  include ::SetUserTypes

  skip_before_action :setup_user, :restrict_user_types
  before_action :setup_captcha_image, only: [:new, :create]
  before_action :set_defaults, only: [:new, :create]

  layout 'external'

  # GET /wpml/registrations/new
  def new
    @header = _('Registration for WPML Clients')
    @registration = Client.new
  end

  # POST /wpml/registrations
  def create
    @registration = Client.new(registration_params)
    # Automatically generate nickname and password (implemented in NormalUser)
    @registration.generate_nickname
    @registration.generate_password
    # Confirm e-mail without sending a confirmation e-mail or requiring any
    # user action. We're skipping e-mail confirmation as these users already
    # purchased WPML, so we assume they are not spammers.
    @registration.confirm_email!

    # Captcha validation
    captcha = CaptchaImage.find(params[:captcha_id].to_i)
    captcha_expected_code = captcha.code.downcase
    captcha_entered_code = params[:captcha_code].downcase
    unless captcha_entered_code && captcha_entered_code == captcha_expected_code
      flash.now[:notice] = "Verification code doesn't match."
      render :new
      return
    end

    if @registration.save
      # Must destroy the captcha or else the same captcha could be used by a
      # script to create multiple accounts
      captcha.destroy if captcha

      # Send welcome e-mail containing the user's password and API key
      Wpml::RegistrationsMailer.welcome(@registration).deliver_now

      # Login the user without requesting credentials
      create_session_for_user(@registration)

      # Render "Welcome" page with instructions on how to insert the API key
      # into WPML.
      render :welcome
    else
      render :new
    end
  end

  private

  # Only allow a trusted parameter "white list" through.
  def registration_params
    params.require(:client).permit(:fname, :lname, :email)
  end

  def setup_captcha_image
    @captcha_image = CaptchaImage.new(content_type: 'image/jpeg', filename: 'captcha.jpg')
    @captcha_image.generate_image
  end

  def set_defaults
    @default_user_agreement = 'User Agreement'.html_safe
    params[:utype] ||= 'Client'
  end
end
