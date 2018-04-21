class PrivateTranslatorsController < ApplicationController
  prepend_before_action :setup_user
  before_action :verify_client, only: [:index, :new, :create, :delete, :resend]
  before_action :verify_translator, only: [:clients, :show, :update]
  before_action :locate_private_translator, except: [:clients, :index, :new, :create]
  layout :determine_layout

  def index
    @header = _('My private translators')
  end

  def clients
    @header = _('My private clients')
  end

  def new
    @header = _('Invite a translator')
  end

  def create
    @fname = params[:fname]
    @lname = params[:lname]
    @email = params[:email]

    private_translator = nil
    @errors = []

    translator = User.where('email=?', @email).first
    newuser = false
    if translator
      if translator[:type] != 'Translator'
        @errors << 'A client with this email already exists. Choose a different email address.'
      end
    else

      base_nickname = @fname + '.' + @lname[0..0]
      nickname_cnt = User.where('nickname LIKE ?', base_nickname + '%').count
      idx = nickname_cnt + 1
      while User.where('nickname = ?', (base_nickname + idx.to_s)).first
        idx += 1
      end
      nickname = base_nickname + idx.to_s

      translator = Translator.new(fname: @fname,
                                  lname: @lname,
                                  email: @email,
                                  nickname: nickname,
                                  userstatus: USER_STATUS_PRIVATE_TRANSLATOR,
                                  password: Digest::MD5.hexdigest(Time.now.to_s)[0..7],
                                  signup_date: Time.now,
                                  notifications: 0)
      newuser = true
      unless translator.save
        translator.errors.full_messages.each { |msg|	@errors << msg }
      end
    end

    if !@errors.empty?
      @header = _('Invite a translator')
      render action: :new
    else
      private_translator = PrivateTranslator.create!(client_id: @user.id, translator_id: translator.id, status: PRIVATE_TRANSLATOR_PENDING)
      if translator.can_receive_emails?
        ReminderMailer.invite_translator(translator, @user, private_translator, newuser).deliver_now
      end
      @header = _('Your invitation was sent')
    end

  end

  def show
    @header = _('Invitation to translate')
  end

  def resend
    if @private_translator.translator.can_receive_emails?
      ReminderMailer.invite_translator(@private_translator.translator, @user, @private_translator, false).deliver_now
      flash[:notice] = _('The invitation to %s has been resent') % @private_translator.translator.full_name
    else
      flash[:notice] = _('This email do not exit. Please try another one. Contact support for more information')
    end
    redirect_to action: :index
  end

  def delete
    @private_translator.destroy
    redirect_to action: :index
  end

  def update
    status = params[:status].to_i
    @private_translator.update_attributes!(status: status)
    redirect_to action: :show, id: @private_translator.id
  end

  private

  def locate_private_translator

    @private_translator = PrivateTranslator.find(params[:id].to_i)
  rescue
    set_err('Cannot find this invitation')
    return false

  end

  def verify_client
    if @user[:type] != 'Client'
      set_err('You cannot access this page')
      false
    end
  end

  def verify_translator
    if @user[:type] != 'Translator'
      set_err('You cannot access this page')
      false
    end
  end
end
