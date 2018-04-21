class BidsController < ApplicationController

  prepend_before_action :setup_user
  before_action :verify_ownership, except: 'unset_all_bids'
  layout :determine_layout
  before_action :setup_help

  def show
    @header = if @user.has_client_privileges?
                _('Bid for translating %s to %s by %s') % [@project.name, @bid.revision_language.language.name, @chat.translator.full_name]
              else
                _('Your bid for translating %s to %s') % [@project.name, @bid.revision_language.language.name]
              end
    @sections = %w(Status Amount)
    @sections << 'Accepted' if @bid.has_accepted_details
  end

  def update
    begin
      days_to_complete = Integer(params[:bid][:days_to_complete])
    rescue
      @warning = _('You need to enter the number of days allowed to complete the work from the bid acceptance date.')
      return
    end

    if days_to_complete > @bid.days_to_complete
      @bid.days_to_complete = days_to_complete
      @bid.save!
      @show_update = true
    else
      @warning = _('You can only extend the delivery deadline, which is currently %s day(s) after the bid acceptance.') % @bid.days_to_complete
    end
  end

  def unset_all_bids
    return unless @user.has_supporter_privileges?

    @translator = Translator.find(params[:translator_id])
    @translator.all_chats_from_bids_that_won.each do |chat|
      chat.bids.first.unset_won
    end
    redirect_to :back
  end

  def unset_bid
    return unless @user.has_supporter_privileges?

    if Bid.find(params[:id]).unset_won
      render html: "<span style='font-weight:bold; color:red;'>(Removed)</span>"
    else
      render html: "<span style='font-weight:bold; color:red;'>Error! not removed!</span>"
    end
  end

  private

  def verify_ownership
    res = do_verify_ownership(project_id: params[:project_id], revision_id: params[:revision_id], chat_id: params[:chat_id], bid_id: params[:id])
    if res
      @show_expiration_edit = @bid.has_expiration_details && (@user[:type] == 'Client')
    end
    res
  end

end
