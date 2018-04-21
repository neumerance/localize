class AttachmentsController < ApplicationController
  prepend_before_action :setup_user
  before_action :verify_ownership
  layout :determine_layout

  def index
    @attachments = @message.attachments
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def create
    begin
      attachment = Attachment.create! params[:attachment]

      @message.attachments << attachment
      @message.save!

      create_new_version(attachment) if @message[:type] == 'VersionUpdate'

      @result = { 'message' => 'Attachment created', 'id' => attachment.id }
    rescue
      @result = { 'message' => 'Attachment failed' }
    end

    # rescue ActiveRecord::RecordInvalid
    #  @result = {"message" => "Attachment failed", "id" => attachment.id}

    respond_to do |format|
      format.html
      format.xml
    end
  end

  def show
    respond_to do |format|
      format.html { send_file(@attachment.full_filename) }
      format.xml
    end
  end

  private

  def verify_ownership
    do_verify_ownership(project_id: params[:project_id], revision_id: params[:revision_id], chat_id: params[:chat_id], message_id: params[:message_id], attachment_id: params[:id])
  end

  def create_new_version(attachment)
    vc = VersionCreator.new
    vc.add_source(attachment.full_filename, 0)

    # create the new version
    version = ::Version.new
    # copy the parameters
    version.content_type = attachment.content_type
    version.filename = 'generated_' + attachment.filename
    version.size = 1
    version.save!

    # create the new file
    vc.generate(version.full_filename)

    # set the file size too
    version.size = File.size(version.full_filename)

    # tie to the revision
    @revision.versions << version
    @revision.save!
  end
end
