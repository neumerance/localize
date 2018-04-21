class DestinationsController < ApplicationController
  prepend_before_action :setup_user, except: [:go]
  before_action :verify_supporter_privileges, except: [:go]
  before_action :locate_destination, except: [:index, :new, :create, :go]
  before_action :set_language_selection, only: [:new, :edit, :create, :update]
  layout :determine_layout

  # GET /destinations
  # GET /destinations.xml
  def index
    @destinations = Destination.order('name ASC').all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render xml: @destinations }
    end
  end

  # GET /destinations/1
  # GET /destinations/1.xml
  def show
    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render xml: @destination }
    end
  end

  # GET /destinations/new
  # GET /destinations/new.xml
  def new
    @destination = Destination.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render xml: @destination }
    end
  end

  # GET /destinations/1/edit
  def edit
    @languages = Language.list_major_first
  end

  # POST /destinations
  # POST /destinations.xml
  def create
    @destination = Destination.new(params[:destination])

    respond_to do |format|
      if @destination.save
        flash[:notice] = 'Destination was successfully created.'
        format.html { redirect_to(@destination) }
        format.xml  { render xml: @destination, status: :created, location: @destination }
      else
        format.html { render action: 'new' }
        format.xml  { render xml: @destination.errors, status: :unprocessable_entity }
      end
    end
  end

  # PUT /destinations/1
  # PUT /destinations/1.xml
  def update
    respond_to do |format|
      if @destination.update_attributes(params[:destination])
        flash[:notice] = 'Destination was successfully updated.'
        format.html { redirect_to(@destination) }
        format.xml  { head :ok }
      else
        format.html { render action: 'edit' }
        format.xml  { render xml: @destination.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /destinations/1
  # DELETE /destinations/1.xml
  def destroy
    @destination.destroy

    respond_to do |format|
      format.html { redirect_to(destinations_url) }
      format.xml  { head :ok }
    end
  end

  def visits
    @header = 'Visits to %s' % @destination.name

    @pager = ::Paginator.new(@destination.visits.count, PER_PAGE) do |offset, per_page|
      @destination.visits.limit(per_page).offset(offset).order('id DESC')
    end

    @visits = @pager.page(params[:page])
    @list_of_pages = []
    for idx in 1..@pager.number_of_pages
      @list_of_pages << idx
    end
    @show_number_of_pages = (@pager.number_of_pages > 1)

  end

  def go
    name = params[:name]
    if name.blank?
      set_err('Name not specified')
      return
    end

    lc = params[:lc]
    language = (Language.where('iso=?', lc).first unless lc.blank?)

    if language
      @destination = Destination.where('(name=?) AND (language_id=?)', name, language.id).first
    end

    @destination = Destination.where('name=?', name).first unless @destination

    if @destination
      @visit = Visit.create!(source: params[:src], destination_id: @destination.id)
      redirect_to @destination.url
    else
      set_err('Cannot find this destination')
      return
    end

  end

  private

  def set_language_selection
    @languages = Language.list_major_first
  end

  def locate_destination

    @destination = Destination.find(params[:id])
  rescue
    set_err('cannot find this destination')
    return false

  end

  def verify_supporter_privileges
    unless @user.has_supporter_privileges?
      set_err('You are not allowed to do this.')
      false
    end
  end

end
