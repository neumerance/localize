class HelpTopicsController < ApplicationController
  prepend_before_action :setup_user
  before_action :verify_supporter_privileges
  before_action :locate_help_topic, except: [:index, :new, :create]
  layout :determine_layout

  def index
    @help_topics = HelpTopic.order('title ASC').all
    @header = 'Help topics'
  end

  def show
    @header = "Help topic - '%s'" % @help_topic.title
  end

  def new
    @header = 'New help topic'
    @help_topic = HelpTopic.new
  end

  # GET /destinations/1/edit
  def edit
    @header = "Edit '%s'" % @help_topic.title
  end

  # POST /destinations
  # POST /destinations.xml
  def create
    @help_topic = HelpTopic.new(params[:help_topic])

    if @help_topic.save
      flash[:notice] = 'Help topic was successfully created.'
      redirect_to(@help_topic)
    else
      @header = 'New help topic'
      render action: 'new'
    end
  end

  # PUT /destinations/1
  # PUT /destinations/1.xml
  def update

    if @help_topic.update_attributes(params[:help_topic])
      flash[:notice] = 'Help topic was successfully updated.'
      redirect_to(@help_topic)
    else
      @header = "Edit '%s'" % @help_topic.title
      render action: 'edit'
    end
  end

  # DELETE /destinations/1
  # DELETE /destinations/1.xml
  def destroy
    @help_topic.destroy
    redirect_to(help_topics_url)
  end

  private

  def locate_help_topic

    @help_topic = HelpTopic.find(params[:id])
  rescue
    set_err('cannot find this help topic')
    return false

  end

  def verify_supporter_privileges
    unless @user.has_supporter_privileges?
      set_err('You are not allowed to do this.')
      false
    end
  end

end
