class HelpGroupsController < ApplicationController
  prepend_before_action :setup_user
  before_action :verify_supporter_privileges
  before_action :locate_help_group, except: [:index, :new, :create]
  layout :determine_layout

  def index
    @help_groups = HelpGroup.order('name ASC').all
    @header = 'Help groups'
  end

  def show
    @header = "Help group - '%s'" % @help_group.name
  end

  def new
    @header = 'New help group'
    @help_group = HelpGroup.new
  end

  # GET /destinations/1/edit
  def edit
    @header = "Edit '%s'" % @help_group.name
  end

  # POST /destinations
  # POST /destinations.xml
  def create
    @help_group = HelpGroup.new(params[:help_group])

    if @help_group.save
      flash[:notice] = 'Help group was successfully created.'
      redirect_to(@help_group)
    else
      @header = 'New help group'
      render action: 'new'
    end
  end

  # PUT /destinations/1
  # PUT /destinations/1.xml
  def update

    if @help_group.update_attributes(params[:help_group])
      flash[:notice] = 'Help group was successfully updated.'
      redirect_to(@help_group)
    else
      @header = "Edit '%s'" % @help_group.name
      render action: 'edit'
    end
  end

  # DELETE /destinations/1
  # DELETE /destinations/1.xml
  def destroy
    @help_group.destroy
    redirect_to(help_groups_url)
  end

  private

  def locate_help_group

    @help_group = HelpGroup.find(params[:id])
  rescue
    set_err('cannot find this help group')
    return false

  end

  def verify_supporter_privileges
    unless @user.has_supporter_privileges?
      set_err('You are not allowed to do this.')
      false
    end
  end

end
