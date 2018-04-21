class AliasProfilesController < ApplicationController
  prepend_before_action :setup_user

  def create_alias
    @auser = User.find(params[:id]) if params[:id]
    new_alias = Alias.new(email: params[:email])
    new_alias.master_account = @auser
    new_alias.set_defaults
    if new_alias.save
      new_alias.alias_profile = AliasProfile.create
    else
      @error = new_alias.errors
    end

    response = if @error
                 render partial: 'new_alias_table_line', locals: { alias_profile: new_alias.alias_profile }
               else
                 render partial: 'edit_alias_table_line', locals: { alias_profile: new_alias.alias_profile }
               end
    respond_to do |f|
      f.js { response }
    end
  end

  def new_alias_table_line
    @auser = User.find(params[:id]) if params[:id]
    render layout: false
  end

  def alias_table_line
    @auser = User.find(params[:user_id]) if params[:user_id]
    @alias_line = AliasProfile.find(params[:id]).user
    render layout: false
  end

  def edit_password
    @alias_profile = AliasProfile.find(params[:id])
    render layout: false
  end

  def update_password
    @alias_profile = AliasProfile.find(params[:id])

    user = @alias_profile.user

    if params[:password] != params[:repeat_password]
      @error = [['Password', 'Passwords do not match']]
      return
    end

    user.password = params[:password]
    logger.debug user.inspect
    if user.save
      InstantMessageMailer.notify_alias_password_changed(user, params[:password]).deliver_now
      InstantMessageMailer.notify_master_alias_password_changed(user, params[:password]).deliver_now
    else
      @error = user.errors
    end
    render layout: false
  end

  def edit_projects
    @alias_profile = AliasProfile.find(params[:id])
    @auser = User.find(params[:user_id])
    render layout: false
  end

  def update_projects
    @auser = User.find(params[:user_id]) if params[:user_id]
    @alias_profile = AliasProfile.find(params[:id])
    unless @alias_profile.update_attributes(params[:alias_profile])
      @error = @alias_profile.errors
    end

    unless @alias_profile.update_projects(params)
      @error ||= @alias_profile.errors
    end
    render layout: false
  end

  def edit_financial
    @alias_profile = AliasProfile.find(params[:id])
    render layout: false
  end

  def update_financial
    @alias_profile = AliasProfile.find(params[:id])
    unless @alias_profile.update_attributes(params[:alias_profile])
      @error = @alias_profile.errors
    end
  end

  def destroy_alias
    @alias_profile = AliasProfile.find(params[:id])
    user = @alias_profile.user
    user.userstatus = USER_STATUS_CLOSED
    user.save

    Project.where(alias_id: @alias_profile.user.id).update_all(alias_id: nil)
    TextResource.where(alias_id: @alias_profile.user.id).update_all(alias_id: nil)

    respond_to do |format|
      format.js
    end
  end

end
