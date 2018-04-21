class SupportFilesController < ApplicationController
  prepend_before_action :setup_user
  before_action :verify_ownership
  layout :determine_layout

  def index
    @support_files = @project.support_files
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def create
    begin
      support_file = SupportFile.create! params[:support_file]
      @project.support_files << support_file

      @project.save!
      @result = { 'message' => 'Support_File created', 'id' => support_file.id }
    rescue ActiveRecord::RecordInvalid
      @result = { 'message' => 'Support_File failed' }
    end
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def show
    respond_to do |format|
      format.html { send_file(@support_file.full_filename) }
      format.xml
    end
  end

  private

  def verify_ownership
    do_verify_ownership(project_id: params[:project_id], support_file_id: params[:id])
  end

end
