class MyController < ApplicationController
  prepend_before_action :setup_user, except: [:invite]
  before_action :setup_help
  layout :determine_layout

  def index
    @header = _('Your affiliate data')
    xml = REXML::Document.new
    link = REXML::Element.new('a', xml)
    link.add_attributes('href' => 'http://www.icanlocalize.com/my/invite/%d' % @user.id)
    link.text = 'ICanLocalize'
    @invitation_html = ''
    xml.write(@invitation_html, 0)
    @invitation_html = @invitation_html.gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;').gsub("'", '&quot;').gsub(' </textarea>', '</textarea>').gsub(/&gt;[ \t\r\n]*&lt;/, '&gt;&lt;').gsub(/[ \t\r\n]*&lt;/, '&lt;').gsub(/&gt;[ \t\r\n]*/, '&gt;')
  end

  def edit
    @header = _('My invitation page')
    @invitation = @user.invitation || Invitation.new
  end

  def update
    @invitation = @user.invitation || Invitation.new(normal_user_id: @user.id)
    if @invitation.update_attributes(params[:invitation])
      flash[:notice] = 'Your invitation has been updated'
    end
    @header = _('My invitation page')
    if @invitation.active == 1
      redirect_to(action: :index)
    else
      render(action: :edit)
    end
  end

  def report
    @header = _('People I referred')
    unless params[:cvsformat].blank?
      csv_txt = (['Type', 'Name', 'Email', 'Total projects'].collect { |f| "\"#{f}\"" }).join(',') + "\r\n"
      @user.invitees.each do |invitee|
        csv_txt += ([invitee[:type], invitee.full_real_name, invitee.email, invitee[:type] == 'Client' ? (invitee.projects.length + invitee.text_resources.length + invitee.websites.length) : 'NA'].collect { |f| "\"#{f}\"" }).join(',') + "\r\n"
      end
      send_data(csv_txt,
                filename: 'affiliate_report.csv',
                type: 'text/plain',
                disposition: 'downloaded')
    end
  end

  def invite
    begin
      user = User.find(params[:id].to_i)
    rescue
      user = nil
      redirect_to '/'
      return
    end
    session[AFFILIATE_CODE_COOKIE] = user.id
    if user && user.invitation && (user.invitation.active == 1)
      @header = '%s invites you to join ICanLocalize' % user.invitation.name
      @name = user.invitation.name
      @message = user.invitation.message
      @date = user.invitation.updated_at
    else
      redirect_to '/site/'
    end
  end
end
