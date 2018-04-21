class VacationsController < ApplicationController
  prepend_before_action :setup_user
  before_action :find_user
  before_action :locate_vacation, only: [:edit, :update, :destroy]
  layout :determine_layout

  def index
    @header = _('Planned leaves for %s') % @auser.full_name
  end

  def new
    @header = _('Add a new planned leave')
    @vacation = Vacation.new
    render action: :edit
  end

  def create
    @vacation = Vacation.new(params[:vacation])
    @vacation.user = @user
    if @vacation.save
      flash[:notice] = _('Leave added')
      redirect_to action: :index
    else
      @header = _('Add a new planned leave')
      render action: :edit
    end
  end

  def update
    @vacation.update_attributes(params[:vacation])
    if @vacation.save
      flash[:notice] = _('Leave updated')
      redirect_to action: :index
    else
      @header = _('Edit leave')
      render action: :edit
    end
  end

  def edit
    @header = _('Edit leave')
  end

  def destroy
    @vacation.destroy
    redirect_to action: :index
  end

  private

  def find_user
    @auser = User.find(params[:user_id].to_i)
  end

  def locate_vacation
    @vacation = Vacation.find(params[:id].to_i)
    if @vacation.user != @user
      set_err(_('You cannot edit this leave'))
      return false
    end
  end
end
