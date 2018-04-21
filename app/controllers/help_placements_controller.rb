class HelpPlacementsController < ApplicationController
  prepend_before_action :setup_user
  before_action :verify_supporter_privileges
  before_action :locate_help_placement, except: [:index, :new, :create]
  before_action :get_options, only: [:new, :create, :edit, :update]
  layout :determine_layout

  USER_KIND = [['Clients', HELP_PLACEMENT_CLIENT],
               ['Translators', HELP_PLACEMENT_TRANSLATOR]].freeze

  def index
    @placements = HelpPlacement.order('controller ASC').all
    @header = 'Help placements'
  end

  def show
    @header = 'Help placement'
  end

  def new
    @header = 'New help placement'
    @help_placement = HelpPlacement.new
  end

  # GET /destinations/1/edit
  def edit
    @header = 'Edit help placement'
  end

  # POST /destinations
  # POST /destinations.xml
  def create
    @help_placement = HelpPlacement.new(params[:help_placement])
    @help_placement.user_match_mask = @help_placement.user_match
    if @help_placement.save
      flash[:notice] = 'Help placement was successfully created.'
      redirect_to(@help_placement)
    else
      @header = 'New help placement'
      render action: 'new'
    end
  end

  # PUT /destinations/1
  # PUT /destinations/1.xml
  def update

    if @help_placement.update_attributes(params[:help_placement])
      @help_placement.user_match_mask = @help_placement.user_match
      @help_placement.save
      flash[:notice] = 'Help placement was successfully updated.'
      redirect_to(@help_placement)
    else
      @header = 'Edit Help Placement' # % @help_placement.title #there is no such title attr
      render action: 'edit'
    end
  end

  # DELETE /destinations/1
  # DELETE /destinations/1.xml
  def destroy
    @help_placement.destroy
    redirect_to(help_placements_url)
  end

  private

  def locate_help_placement

    @help_placement = HelpPlacement.find(params[:id])
  rescue
    set_err('cannot find this help placement')
    return false

  end

  def verify_supporter_privileges
    unless @user.has_supporter_privileges?
      set_err('You are not allowed to do this.')
      false
    end
  end

  def get_options
    @help_topics = HelpTopic.all.order('title ASC').collect { |h| [h.title, h.id] }
    @help_groups = HelpGroup.all.order('name ASC').collect { |h| [h.name, h.id] }
    @user_options = USER_KIND
  end

end
