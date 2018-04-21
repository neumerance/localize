class ManagedWorksController < ApplicationController
  prepend_before_action :setup_user
  before_action :locate_work, except: [:index, :create, :bulk_assign_reviewer]
  before_action :verify_client, except: [:show, :be_reviewer, :resign_reviewer, :bulk_assign_reviewer]
  before_action :can_modify, only: [:enable, :disable]
  before_action :setup_help
  before_action :create_reminders_list, only: [:index, :show]
  layout :determine_layout

  def create
    begin
      from_lang = Language.find(params[:from_language_id].to_i)
    rescue
      set_err('cannot find from language')
      return
    end

    begin
      to_lang = Language.find(params[:to_language_id].to_i)
    rescue
      set_err('cannot find destination language')
      return
    end

    owner_type = params[:owner_type]
    owner_id = params[:owner_id].to_i

    if owner_type == 'ResourceLanguage'
      begin
        work = ResourceLanguage.find(owner_id)
      rescue
        set_err('cannot find owner')
        return
      end
    elsif owner_type == 'WebMessage'
      begin
        work = WebMessage.find(owner_id)
      rescue
        set_err('cannot find owner')
        return
      end
    elsif owner_type == 'RevisionLanguage'
      begin
        work = RevisionLanguage.find(owner_id)
      rescue
        set_err('cannot find owner')
        return
      end
    elsif owner_type == 'WebsiteTranslationOffer'
      begin
        work = WebsiteTranslationOffer.find(owner_id)
      rescue
        set_err('cannot find owner')
        return
      end
    else
      set_err('unsupported work type: %s' % owner_type)
      return
    end

  end

  def enable
    if @managed_work.has_escrow?
      @managed_work.wait_for_payment
    else
      @managed_work.activate
    end
  end

  def disable
    @managed_work.disable
  rescue => e
    Rails.logger.error "Error #{e.message} : #{e.inspect}"
  end

  def remove_translator
    unless @user.has_supporter_privileges?
      set_err("You can't do that")
      return
    end
    @managed_work.update_attribute :translator_id, nil

    flash[:notice] = 'Translator removed'
    redirect_to :back
  end

  # The name of the method is misleading. It's used to assign a reviewer to a
  # manual assignment language pair. Do *NOT* use this for website translation
  # projects, use Wpml::WebsitesController#assign_reviewer instead.
  def set_translator
    unless @user.has_supporter_privileges?
      set_err("You can't do that")
      return
    end

    translator = Translator.find_by(nickname: params[:nickname])
    unless translator
      flash[:notice] = 'Reviewer not found'
      redirect_to :back
      return
    end

    begin
      @managed_work.assign_reviewer(translator.id)
      flash[:notice] = 'Reviewer assigned'
    rescue StandardError => e
      flash[:notice] = e.message
    end
    redirect_to :back
  end

  def update_status
    unless @user.can_modify?(@managed_work.owner_project)
      set_err("can't edit this project")
      return
    end

    set_err('missing active value') if params[:active].blank?
    active = params[:active].to_i
    owner = @managed_work.owner

    @managed_work.active = active
    if active == MANAGED_WORK_INACTIVE
      # @managed_work.translator = nil

      if owner.is_a? WebsiteTranslationOffer
        # look for jobs in progress
        # for all jobs in progress, set the owner ID as minus the offer_id. This is the same as clearing the translator, but it helps find those jobs later
        @user.managed_works.where('(translation_status IN (?)) AND (owner_type = ?)', [MANAGED_WORK_REVIEWING, MANAGED_WORK_WAITING_FOR_REVIEWER], 'RevisionLanguage').each do |mw|
          if mw.owner.revision.cms_request && (mw.owner.revision.cms_request.website == owner.website)
            mw.update_attributes(translator_id: -owner_id)
          end
        end
      elsif owner.is_a? ResourceLanguage
        # refund review funds
        owner.refund_review
      end
    end
    @managed_work.save

    work = @managed_work.owner

    # update the status of resource chats to indicate who needs to review (Reviewer or translator)
    if (work.class == ResourceLanguage) && work.selected_chat
      if (work.selected_chat.translation_status == RESOURCE_CHAT_TRANSLATOR_NEEDS_TO_REVIEW) && (active == MANAGED_WORK_ACTIVE)
        # Reviewer have to review
        work.selected_chat.update_attributes(translation_status: RESOURCE_CHAT_TRANSLATION_COMPLETE)
      elsif (work.selected_chat.translation_status == RESOURCE_CHAT_TRANSLATION_COMPLETE) && (active == MANAGED_WORK_INACTIVE)
        # Translator have to review
        work.selected_chat.update_attributes(translation_status: RESOURCE_CHAT_TRANSLATOR_NEEDS_TO_REVIEW)
      end
    end

    @review_change_needs_refresh = params[:review_change_needs_refresh].present?

    wc = @managed_work.resource_language.count_untraslated_words(false)
    review_wc = 0
    if @managed_work.resource_language.review_enabled?
      review_wc = @managed_work.resource_language.unfunded_words_pending_review_count(false)
    end

    needs = ActiveSupport::OrderedHash.new
    needs[:translation] = wc > 0
    needs[:review] = @managed_work.resource_language.review_enabled? && (review_wc > 0 || wc > 0)

    needs_text = needs.find_all { |_k, v| v == true }.map { |k, _v| k }
    case needs_text.size
    when 1
      checkbox_label = 'Ready to start %s (%d words, %.2f USD)' % (needs_text + [wc, @managed_work.resource_language.cost])
    when 2
      checkbox_label = 'Ready to start %s and %s (%d words, %.2f USD)' % (needs_text + [wc, @managed_work.resource_language.cost])
    when 3
      checkbox_label = 'Ready to start %s and %s with %s (%d words, %.2f USD)' % (needs_text + [wc, @managed_work.resource_language.cost])
    end

    @checkbox_label = checkbox_label
    @button_div_id = "#ManagedWorkFor#{work.class}#{work.id}"
    @label_div_id = "#chat_#{@managed_work.to_language_id}_label"
    @work = work
  end

  def be_reviewer
    if @user[:type] != 'Translator'
      @msg = 'Must be a translator'
      set_err(@msg)
      return
    end

    # check that the translator is qualified in that language pair
    if !@managed_work.enabled?
      @msg = 'This review job is closed.'
      flash[:notice] = @msg
    elsif !@managed_work.translator_can_apply_to_review(@user)
      @msg = 'You cannot be the reviewer for this job.'
      flash[:notice] = @msg
    elsif @managed_work.translator
      @msg = 'Another translator has already taken this job'
      flash[:notice] = @msg
    else
      @managed_work.translator = @user

      # check if the managed work should begin
      if @managed_work.translation_status == MANAGED_WORK_WAITING_FOR_REVIEWER
        @managed_work.translation_status = MANAGED_WORK_REVIEWING
      end

      # make sure TA sees this too
      if @managed_work.owner.class == WebsiteTranslationOffer
        # look for jobs in progress that were abandoned
        ManagedWork.where('(translator_id = ?) AND (owner_type = ?)', -@managed_work.owner_id, 'RevisionLanguage').each do |mw|
          mw.update_attributes(translator_id: @user.id)
          logger.info "--#{@user.nickname} is now reviewer. His level is #{@user.level} and his raw_rating is #{@user.raw_rating}. Raw rating just calculated is #{@user.calc_raw_rating}"
        end
      elsif @managed_work.owner.class == RevisionLanguage
        @managed_work.owner.revision.count_track
      end

      @managed_work.save
      flash[:notice] = 'You are now the reviewer for this project between %s and %s' % [@managed_work.from_language.name, @managed_work.to_language.name]
    end

    respond_to do |f|
      f.html do
        if request.referer
          redirect_to request.referer
        else
          redirect_to action: :show
        end
      end
      f.js do
        render plain: 'window.location.reload()'
      end
    end
  end

  def resign_reviewer
    if @user != @managed_work.translator
      @msg = 'You are not the reviewer for this project'
      set_err(@msg)
      return
    end

    # check that the translator is qualified in that language pair
    @managed_work.translator = nil

    # check if the managed work should begin
    if @managed_work.translation_status == MANAGED_WORK_REVIEWING
      @managed_work.translation_status = MANAGED_WORK_WAITING_FOR_REVIEWER
    end

    # abort from other review jobs in this project
    if @managed_work.owner.class == WebsiteTranslationOffer
      # look for jobs in progress
      # for all jobs in progress, set the owner ID as minus the offer_id. This is the same as clearing the translator, but it helps find those jobs later
      @user.managed_works.where('(translation_status IN (?)) AND (owner_type = ?)', [MANAGED_WORK_REVIEWING, MANAGED_WORK_WAITING_FOR_REVIEWER], 'RevisionLanguage').each do |mw|
        if mw.owner.revision.cms_request && (mw.owner.revision.cms_request.website == @managed_work.owner.website)
          mw.update_attributes(translator_id: -@managed_work.owner_id)
        end
      end
    end

    @managed_work.save!
    flash[:notice] = 'Resign complete'

    respond_to do |f|
      f.html do
        if request.referer
          redirect_to request.referer
        else
          redirect_to controller: :translator
        end
      end
      f.js
    end
  end

  def unassign_reviewer
    return unless @user.has_supporter_privileges?

    if ManagedWork.find(params[:id]).unassign_reviewer
      render html: "<span style='font-weight:bold; color:red;'>(Removed)</span>"
    else
      render html: "<span style='font-weight:bold; color:red;'>Error! not removed!</span>"
    end

  end

  def assign_reviewer
    return unless @user.has_supporter_privileges?

    to_assign = User.find_by(nickname: params[:translator][:nickname])
    begin
      raise 'Invalid nickname' if to_assign.nil?
      ManagedWork.find(params[:id]).assign_reviewer(to_assign.id)
    rescue => error
      render html: "<span style='font-weight:bold; color:red;'>Error: #{error}</span>"
    else
      render html: "<span style='font-weight:bold; color:red;'>Assigned to <a href='/users/#{to_assign.id}'>#{to_assign.nickname}</a></span>"
    end

  end

  def bulk_assign_reviewer
    return unless @user.has_supporter_privileges?

    managed_works = ManagedWork.find(params[:managed_work_ids])
    new_reviewer = User.find_by(nickname: params[:translator][:nickname])
    if new_reviewer
      flash[:notice] = ''
      managed_works.each do |mw|
        begin
          mw.assign_reviewer(new_reviewer.id)
        rescue => error
          flash[:notice] += "On review #{mw.id}: #{error}\n"
        end
      end
    else
      flash[:notice] = "Can't find reviewer with this nickname"
    end

    redirect_to :back
  end

  private

  def locate_work

    @managed_work = ManagedWork.find(params[:id].to_i)
  rescue
    set_err('cannot find work')
    return

  end

  def verify_client; end

  def can_modify
    can_modify_obj = nil
    case @managed_work.owner
    when RevisionLanguage
      can_modify_obj = @managed_work.owner.revision
    when ResourceLanguage
      can_modify_obj = @managed_work.owner.text_resource
    when WebMessage
      can_modify_obj = @managed_work.owner
    when WebsiteTranslationOffer
      can_modify_obj = @managed_work.owner.website
    end

    unless can_modify_obj && @user.can_modify?(can_modify_obj)
      set_err("Can't do this")
      return false
    end
  end
end
