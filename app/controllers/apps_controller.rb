class AppsController < ApplicationController

  layout :determine_layout

  def new_sisulizer
    @header = _('Upload a Sisulizer project')
    @back = session[:back]
  end

  def create_sisulizer
    @header = _('Word count results')

    @back = request.referer.blank? ? { action: :new_sisulizer } : request.referer

    @version = ::Version.new(params[:version])
    if @version.save
      begin
        @orig_language, @word_count = @version.update_sisulizer_statistics
      rescue
        @orig_language = nil
        @word_count = {}
      end
      if !@orig_language || (@word_count == {})
        flash[:notice] = 'This file does not look like a Sisulizer project.'
        redirect_to action: :new_sisulizer
      end
    else
      flash[:notice] = 'No file selected, please try again'
      session[:back] = @back
      redirect_to action: :new_sisulizer
    end

    # version.destroy
  end

  def available_languages
    @header = _('Languages we can translate between')
  end

end
