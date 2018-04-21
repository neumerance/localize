class OpenWorkController < ApplicationController

  layout :determine_layout

  def index
    @revisions = Revision.find_by_sql("SELECT DISTINCT r.*
			FROM revisions r
			WHERE
			EXISTS (
				SELECT rl.id from revision_languages rl WHERE (rl.revision_id = r.id) AND NOT EXISTS (
					SELECT b.id FROM bids b
					WHERE (b.revision_language_id = rl.id) AND (b.won = 1)
				)
			)
			AND (r.released = 1) AND (UNIX_TIMESTAMP(r.bidding_close_time) > #{Time.now.to_i}) ORDER BY r.id DESC;")

    @offers = WebsiteTranslationOffer.offers_for_supporter

    @web_messages = WebMessage.old_untranslated

    @header = _('Open Projects')
  end

  def show
    begin
      @revision = Revision.find(params[:id].to_i)
    rescue
      redirect_to('/')
      return
    end

    if @revision.released != 1
      redirect_to('/')
      return
    end

    @header = _('Project Overview')

  end

end
