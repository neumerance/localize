class UserClicksController < ApplicationController
  prepend_before_action :setup_user
  layout :determine_layout
  before_action :verify_admin

  def index
    if @auser
      @header = 'Clicks for %s' % @auser.full_name
      @pager = ::Paginator.new(@auser.user_clicks.count, PER_PAGE) do |offset, per_page|
        @auser.user_clicks.limit(per_page).offset(offset).order('user_clicks.id DESC')
      end
    else
      @header = 'Error reports'
      @pager = ::Paginator.new(UserClick.errors.count, PER_PAGE) do |offset, per_page|
        UserClick.errors.limit(per_page).offset(offset).order('user_clicks.id DESC')
      end
    end
    @user_clicks = @pager.page(params[:page])
    @list_of_pages = (1..@pager.number_of_pages).to_a
  end

  def show
    @header = 'Details for click'
    begin
      @user_click = UserClick.find(params[:id].to_i)
    rescue
      set_err('cannot find click')
      return
    end
    if @user_click.user_id != params[:user_id].to_i
      set_err("Click doesn't belog to user")
      return
    end
    @auser = @user_click.user
  end

  private

  def verify_admin
    unless @user.has_admin_privileges?
      set_err('You do not have permission to do that')
      return false
    end

    @auser = User.find(params[:user_id].to_i) if params[:user_id]

  end

end
