class FeedbacksController < ApplicationController
  prepend_before_action :setup_user, except: [:new, :create]

  before_action :locate_owner, except: [:index, :show]
  before_action :locate_feedback, except: [:index, :new, :create, :list]

  layout :determine_layout

  RATING_TEXT = { 1 => N_('Bad'),
                  2 => N_('OK'),
                  3 => N_('Excellent') }.freeze

  FEEDBACK_STATUS_TEXT = { FEEDBACK_CREATED => N_('Created'),
                           FEEDBACK_HANDLED => N_('Handled'),
                           FEEDBACK_IGNORED => N_('Ignored') }.freeze

  def list
    @header = _('Feedback received')
    @feedbacks = @owner.feedbacks
  end

  def show
    @header = _('Feeback details')
  end

  def new
    @header = _('Give Us Feedback')
  end

  def create
    @header = _('Thank You!')
    feedback = Feedback.new(params[:feedback])
    feedback.txt = feedback.rating == 2 ? params[:txt2] : (feedback.rating == 1 ? params[:txt1] : nil)
    feedback.owner = @owner
    feedback.translator = @translator
    feedback.from_language = @orig_language
    feedback.to_language = @translation_language
    feedback.save

    if @translator && (feedback.rating != 3) && !feedback.txt.blank?
      if @translator.can_receive_emails?
        ReminderMailer.feedback_from_visitor(@translator, feedback).deliver_now
      end
    end
  end

  private

  def locate_owner
    @owner_type = params[:ot]
    @owner_id = params[:oi].to_i
    if @owner_type == 'RL'
      begin
        @owner = ResourceLanguage.find(@owner_id)
        @orig_language = @owner.text_resource.language
        @translation_language = @owner.language
        @translator = @owner.selected_chat ? @owner.selected_chat.translator : nil
        @client = @owner.text_resource.client
        session[AFFILIATE_CODE_COOKIE] = @client.id
      rescue
      end
    end

    if @translation_language
      @locale = @translation_language.name
      set_locale @locale
    end

    unless @owner
      set_err('Cannot locate owner')
      return false
    end
  end

  def locate_feedback
    begin
      @feedback = Feedback.find(params[:id].to_i)
    rescue
      set_err('cannot locate this feedback')
      return false
    end

    if @feedback.owner.class == ResourceLanguage
      @client = @feedback.owner.text_resource.client
      @translator = @feedback.owner.selected_chat ? @feedback.owner.selected_chat.translator : nil
    end

    if @user.has_supporter_privileges? || (@user == @client) || (@user == @translator)
      return
    else
      set_err('Not your feedback')
      return false
    end
  end

end
