class VersionsController < ApplicationController
  include ::NotifyTas
  include ::Reminders
  include ::VersionsMethods

  prepend_before_action :setup_user

  # disable CSRF token check to be able to accept requests from WPML
  skip_before_action :verify_authenticity_token

  before_action :verify_ownership
  layout :determine_layout

  def index
    if !params[:alternate_user_id].blank?
      begin
        user = User.find(params[:alternate_user_id].to_i)
      rescue
        set_err('Cannot find user')
        return
      end
    else
      user = @user
    end

    @versions = @revision.user_versions(user)
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def create
    unless @user.can_modify?(@revision)
      set_err("You can't edit this project")
      return
    end
    # check if this upload is permitted
    @tas_completion_notification_sent = []
    manual_upload = !params[:do_zip].blank?
    if (@user.is_client? && @revision.client_can_create_version) || ((@user[:type] == 'Translator') && @revision.translator_can_create_version(@user))
      created_ok = false
      begin
        version = ::Version.new(params[:version])
        version.save!
        created_ok = true
      rescue ActiveRecord::RecordInvalid
        @result = { 'message' => 'Version failed' }
      end

      if created_ok
        # add this version to the revision
        # indicate that this version was posted by this user
        version.revision = @revision
        version.user = @user.master_account || @user
        version.save!
      end

      if created_ok && !manual_upload
        unless version.update_statistics(@user)
          # TODO: Sometimes the version is destroyed and the cms_request end up waiting
          # 	for translator as if the project setup were completed, but with WC = 0
          #   I've added some logs on the update_statistics but may is better to
          #   don't destroy the file.
          logger.error 'VERSION DESTROYED: For an unknown reason icl was not able to update_statistics for this version'
          logger.error(version.to_yaml.to_s)
          logger.error '-------------------------------------------------'

          version.destroy
          @result = { 'message' => "Version doesn't contain text" }
          created_ok = false
        end
      end

      if created_ok
        if @user[:type] == 'Translator'
          logger.info 'Version created by translator, executing send_output_notification()...'
          send_output_notification(version, @user)
        end
        @revision.count_track
        @revision.update_attributes!(update_counter: @revision.update_counter + 1)
        @result = { 'message' => 'Version created', 'id' => version.id }
      end
    else
      @result = { 'message' => 'Cannot create a new version', 'reason' => "translator_can_create_version: #{@revision.translator_can_create_version(@user)}, usertype: #{@user[:type]}" }
    end

    respond_to do |format|
      format.html do
        redirect_to controller: :revisions, action: :show, project_id: @project.id, id: @revision.id, anchor: 'client_version'
      end
      format.xml
    end
  end

  def duplicate_complete
    if Rails.env == 'production'
      set_err('cannot do this')
      return
    end

    # check if this upload is permitted
    @tas_completion_notification_sent = []
    if (@user[:type] == 'Translator') && @revision.translator_can_create_version(@user)
      version = auto_complete_version(@version, @user)
      if version
        @result = { 'message' => 'Version created', 'id' => version.id }
      end
    else
      @result = { 'message' => 'Cannot create a new version', 'reason' => "translator_can_create_version: #{@revision.translator_can_create_version(@user)}, usertype: #{@user[:type]}" }
    end

    respond_to do |format|
      format.html do
        flash[:notice] = 'New version auto-created'
        chat = @revision.chats.where(['translator_id=?', @user.id]).first
        redirect_to(controller: :chats, action: :show, project_id: @project.id, revision_id: @revision.id, id: chat.id)
      end
      format.xml
    end
  end

  # This method is called from TA Client when submiting a new version
  def update
    if @user.has_client_privileges? && @revision.client_can_update_version
      if @version
        begin
          new_params = params[:version].merge(chgtime: Time.now)

          # TA takes the latest version bassed on the id only, so if a customer
          #   updates the version translators never receives the updated content
          #   because translated content will always have a greater id.
          # Check tests -> create_project_and_revision_tests.rb:120~
          #		However this only happen if project is not released yet, so it's not clear
          #		for me how can be a translated version.
          #		This needs more checking below code was enabled on 740cc978
          #		I'm disabling on  Oct-06-2016 while fixing tests - Arnold
          #
          # logger.info "Creating a new version instead of update..."
          # new_file = ActionController::TestUploadedFile.new(@version.full_filename)
          # @version = @version.clone
          # @version.uploaded_data = new_file
          # @version.save
          # --------

          @version.update_attributes(new_params)
          @version.update_statistics(@user)
          @result = { 'message' => 'Version updated', 'id' => @version.id }
          @revision.update_attributes!(update_counter: @revision.update_counter + 1)

          if @version.revision.from_cms?
            cms_target_language = @version.revision.cms_request.cms_target_language
            wc = @version.revision.lang_word_count(cms_target_language.language)
            cms_target_language.update_attribute :word_count, wc
          end
        rescue ActiveRecord::RecordInvalid
          @result = { 'message' => 'Version failed' }
        end
      else
        @result = { 'message' => 'Cannot locate version', 'id' => params[:id] }
      end
    else
      @result = { 'message' => 'Cannot update version' }
    end

    respond_to do |format|
      format.html
      format.xml
    end
  end

  def show

    # access is granted if it's this user's version or created by the client and for reviewers
    if (@user[:type] == 'Translator') && (@version.user != @user) && !@version.user.has_client_privileges? && !@is_reviewer
      set_err('You cannot access this version')
      return false
    end

    # clear translator reminders about accepted bids
    if @user[:type] == 'Translator' && @version.user.has_client_privileges? && !@is_reviewer
      chat = Chat.where(['revision_id =? AND translator_id =?', @revision.id, @user.id]).first
      chat.bids.each { |bid| delete_reminder_for_bid(bid, @user) }
    end

    unless @version.user
      @version.build_user(id: -1, type: 'Translator', fname: 'Expired/Unknown', lname: 'User')
    end

    respond_to do |format|
      format.html do
        if params[:unzip].to_i == 1
          send_data(@version.get_contents,
                    filename: @version.orig_filename,
                    type: 'text/plain',
                    disposition: 'downloaded')
        else
          send_file(@version.full_filename)
        end
      end
      format.xml
    end
  end

  private

  def verify_ownership

    do_verify_ownership(project_id: params[:project_id], revision_id: params[:revision_id], version_id: params[:id])
  end

end
