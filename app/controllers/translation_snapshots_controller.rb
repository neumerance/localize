class TranslationSnapshotsController < ApplicationController

  class InvalidSnapshot < StandardError; end
  ERR_CREATING_SNAPSHOT = -1
  ERR_CREATING_LANGUAGES = -2
  ERR_CREATING_PROFILE = -3
  ERR_UNKNOWN_LANGUAGES = -4
  ERR_UNKNOWN_WEBSITE = -5
  ERR_DUPLICATE_DATE = -6
  ERR_FROM_FUTURE = -7

  def create_by_cms
    begin
      website_id = params[:website_id]
      website = Website.find_by(id: website_id, accesskey: params[:accesskey])

      unless website
        @err_code = ERR_UNKNOWN_WEBSITE
        raise InvalidSnapshot, "Can't find this website"
      end

      if website.client.anon == 1
        @err_code = ERR_CREATING_PROFILE
        raise InvalidSnapshot, 'This user is anonymous'
      end

      from_language = Language.find_by(name: params[:from_language_name])
      to_language = Language.find_by(name: params[:to_language_name])
      unless from_language && to_language
        @err_code = ERR_UNKNOWN_LANGUAGES
        raise InvalidSnapshot, 'Unknown languages'
      end

      profile = website.translation_analytics_profile
      unless profile
        begin
          profile = TranslationAnalyticsProfile.new
          website.translation_analytics_profile = profile
          website.save!
        rescue => e
          @err_code = ERR_CREATING_PROFILE
          raise InvalidSnapshot, 'Error creating translation analytics profile'
        end
      end

      language_pair = profile.translation_analytics_language_pairs.find_by(
        from_language_id: from_language.id, to_language_id: to_language.id
      )

      unless language_pair
        begin
          language_pair = profile.add_language_pair(from_language, to_language)
        rescue => e
          @err_code = ERR_CREATING_LANGUAGES
          raise InvalidSnapshot, 'Error creating the languages'
        end
      end

      if language_pair.translation_snapshots.find_by(date: params[:date].to_date)
        @err_code = ERR_DUPLICATE_DATE
        raise InvalidSnapshot, 'Already sent a snapshot this day'
      end

      if params[:date].to_date > Date.today
        @err_code = ERR_FROM_FUTURE
        raise InvalidSnapshot, 'Snapshot from future'
      end

      @translation_snapshot = TranslationSnapshot.new
      @translation_snapshot.date = params[:date]
      @translation_snapshot.translated_words = params[:translated_words]
      @translation_snapshot.words_to_translate = params[:words_to_translate]
      begin
        language_pair.translation_snapshots << @translation_snapshot
        @status = 'success'
        @err_code = 0
      rescue => e
        puts e.inspect
        puts e.backtrace
        @err_code = ERR_CREATING_SNAPSHOT
        raise InvalidSnapshot, 'Error creating snapshot'
      end

    rescue InvalidSnapshot => e
      Rails.logger.info e.message
      @status = e.message
    end

    respond_to do |format|
      format.xml { render layout: 'xmlbase' }
    end
  end
end
