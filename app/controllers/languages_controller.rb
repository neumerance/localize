class LanguagesController < ApplicationController
  prepend_before_action :setup_user, except: ['language_pairs']
  layout :determine_layout

  def index
    @header = _('Languages')
    @languages = Language.all
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def language_pairs
    @languages = Language.all
    @languages_to = {}

    @languages.each do |l|
      @languages_to[l.id] = l.available_language_froms.map { |al| al.to_language.name }.uniq.sort
    end
  end

end
