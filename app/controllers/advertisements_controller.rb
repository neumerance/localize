class AdvertisementsController < ApplicationController
  prepend_before_action :setup_user
  layout :determine_layout
  # before_filter :setup_item, :except=>[:index, :new, :create]
  before_action :verify_admin

  def index
    @header = 'Advertisements for potential customers'
    @advertisements = Advertisement.all
  end

  def new
    @header = 'Create a new advertisement'
    @advertisement = Advertisement.new
    @goto_action = :create
    @methodto = 'POST'
    render action: :edit
  end

  def create
    @advertisement = Advertisement.new(params[:advertisement])

    if @advertisement.save
      flash[:notice] = 'Advertisement created OK'
      redirect_to action: :show, id: @advertisement.id
    else
      @header = 'Create a new advertisement'
      @goto_action = :create
      @methodto = 'POST'
      render action: :edit
    end
  end

  def edit
    @advertisement = Advertisement.find(params[:id])
    @header = 'Edit advertisement'
    @editing = true
    @goto_action = :update
    @methodto = 'PUT'
  end

  def update
    @advertisement = Advertisement.find(params[:id])
    @advertisement.update_attributes(params[:advertisement])

    if @advertisement.save
      flash[:notice] = 'Advertisement changed OK'
      redirect_to action: :show, id: @advertisement.id
    else
      @header = 'Edit advertisement'
      @editing = true
      @goto_action = :update
      @methodto = 'PUT'
      render action: :edit
    end
  end

  def show
    @advertisement = Advertisement.find(params[:id])
    @header = 'Advertisement details'
  end

  def delete
    advertisement = Advertisement.find(params[:id])
    advertisement.destroy
    flash[:notice] = 'Advertisement deleted'
    redirect_to action: :index
  end

  private

  def verify_admin
    @user.has_admin_privileges?
  end

end
