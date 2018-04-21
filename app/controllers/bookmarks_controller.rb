class BookmarksController < ApplicationController
  prepend_before_action :setup_user
  layout :determine_layout
  before_action :verify_ownership, except: [:index, :new, :create]
  before_action :setup_help

  def index
    @header = 'Your bookmarks'
    @bookmarks = @user.bookmarks
    # @show_bookmark_edit = true
  end

  def show
    @header = "Bookmark to #{@bookmark.name}"
  end

  def new
    begin
      @auser = User.find(params[:bookmark_user_id])
      @header = "Add #{@auser.full_name} to your bookmarks"
    rescue
      flash[:notice] = 'Cannot find this user'
      redirect_to action: :index
      return
    end
    @bookmark = Bookmark.new
    @bookmark.resource = @auser
  end

  def create
    ok = false
    @bookmark = Bookmark.new(params[:bookmark])

    if @user.bookmarks.find_by(resource_id: params[:bookmark][:resource_id], resource_type: 'User')
      @bookmark.errors.add(:base, 'You already added feedback to this user, if you want to modify it please contact our support team creating a ticket.')
    else
      @auser = User.find(@bookmark.resource_id)
      @bookmark.resource = @auser

      @has_money_transaction = MoneyTransaction.where('(source_account_id=?) OR (target_account_id=?)', @auser.money_account.owner_id, @auser.money_account.owner_id).first

      unless @user.has_translator_privileges? || !@user.money_account.payments.empty?
        flash[:notice] = "The user doesn't have any payment, you can't add it."
        redirect_to :back
        return
      end

      @bookmark.user = @user.master_account || @user
      ok = @bookmark.save
    end

    respond_to do |format|
      if ok
        flash[:notice] = 'Bookmark was successfully created.'
        format.html { redirect_to_prev('Bookmark was successfully created.', 3) }
        format.xml { head :created, location: bookmark_url(@bookmark) }
      else
        format.html do
          flash[:notice] = @bookmark.errors.full_messages.join '\n'
          redirect_to :back
        end
        format.xml { render xml: @bookmark.errors.to_xml }
      end
    end
  end

  def edit
    @show_bookmark_edit = nil # set the default value - don't show the list
    req = params[:req]
    @show_bookmark_edit = true if req == 'show'
  end

  def update
    @bookmark.update_attributes(params[:bookmark])
    @show_bookmark_edit = true unless @bookmark.save!
  end

  def destroy
    @user.bookmarks.delete(@bookmark)
    @bookmark.destroy
    @user.save!
  end

  private

  def verify_ownership
    # set up the bookmark

    @bookmark = Bookmark.find(params[:id])
  rescue
    set_err('Cannot find this bookmark')
    return false

  end

  def redirect_to_prev(status, level)
    begin
      prev_url = session[:last_url][-level]
    rescue
      prev_url = nil
    end

    if prev_url && (prev_url != request.url)
      redirect_to(prev_url)
    else
      redirect_after_login(status)
    end
  end
end
