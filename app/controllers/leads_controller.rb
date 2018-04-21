require 'csv'

class LeadsController < ApplicationController

  prepend_before_action :setup_user
  layout :determine_layout
  # before_filter :setup_item, :except=>[:index, :new, :create]
  before_action :verify_admin

  def index
    @header = 'Leads to potential customers'
    @leads = Lead.all
  end

  def new
    @header = 'Upload a new CSV file'
    @advertisements = Advertisement.all
  end

  def create

    begin
      advertisement = Advertisement.find(params[:ad])
    rescue
      flash[:notice] = 'No advertisement selected'
      redirect_to action: :new
      return
    end

    begin
      txt = params[:file].read
    rescue
      flash[:notice] = 'No CSV file selected'
      redirect_to action: :new
      return
    end

    cnt = 0
    ignored = 0
    begin
      CSV::Reader.parse(txt) do |row|
        if cnt >= 2
          lead = Lead.new(name: row[0],
                          url: row[1],
                          description: row[2],
                          contact_title: row[3],
                          contact_fname: row[4],
                          contact_lname: row[5],
                          contact_email: row[6],
                          addr_country: row[7],
                          addr_state: row[8],
                          addr_city: row[9],
                          addr_zip: row[10],
                          addr_street: row[11],
                          phone: row[12])
          lead.advertisement = advertisement
          ignored += 1 unless lead.save
        end
        cnt += 1
      end
    rescue
      flash[:notice] = 'Bad file format. Must be a CSV with appropriate fields'
      redirect_to action: :new
      return
    end
    cnt -= 2
    flash[:notice] = "Added #{cnt - ignored} rows. Ignored #{ignored} duplicates."
    redirect_to action: :index
  end

  def show
    @header = 'Lead details'
    @lead = Lead.find(params[:id])
  end

  private

  def verify_admin
    @user.has_admin_privileges?
  end

end
