require 'json'
require 'set'

class TranslationAnalyticsController < TranslationAnalyticsBaseController
  prepend_before_action :from_cms
  prepend_before_action :setup_user
  layout :determine_layout

  PROGRESS_GRAPH_MIN_SIZE = 4 # in snapshots
  MAX_SNAPSHOTS = 5000

  # This is not linked anywhere. It is only to help
  # on the development. No issue in case a client
  # discover this link.
  def index
    @websites = @user.websites_for_translation_analytics
  end

  # The overview action shows the current state of a project.
  def overview
    @project = get_project
    @project.translation_analytics_profile ||= TranslationAnalyticsProfile.new
    @translation_analytics_profile = @project.translation_analytics_profile

    if @translation_analytics_profile.translation_snapshots.count > 1
      @bars_data = setup_overview_languages_data(@project)
    else
      @hide_data = true
    end

    raise "You can't do this" unless @user.has_supporter_privileges? || (@project.client == @user)

    @selected_tab = :overview
    render layout: @layout
  end

  # This action shows the progress of translations over the time, in a line graph.
  def progress_graph
    @project = get_project
    @language_pairs = @project.translation_analytics_language_pairs
    @selected_language_pair_id = params[:language_pair_id] || '-1'

    raise "You can't do this" unless @user.has_supporter_privileges? || (@project.client == @user)

    snapshots_count = @project.translation_analytics_profile.translation_snapshots.count
    if snapshots_count < PROGRESS_GRAPH_MIN_SIZE
      @hide_progress_graph = true
      @missing_days = PROGRESS_GRAPH_MIN_SIZE - snapshots_count
    else
      # The selector on the screen changes if we are going to show one graph fro all languages
      # or one graph per language. It uses selected_language_pair_id because there was an option
      # to show the graph for only one language. I left as it is to enable this support in the
      # future if needed.
      if @selected_language_pair_id.to_i == -1 # all languages in one graph
        @one_graph_per_language = true
        @graph_title = 'Status for all languages'
        @language_pairs_data = @project.translation_analytics_language_pairs.map do |lp|
          [lp, setup_progress_graph_data(@project, lp)]
        end
      else # one graph per language
        @graph_title = 'All languages overview'
        @language_pairs_data = [[@language_pairs.first, setup_progress_graph_data(@project)]]
      end
    end

    @selected_tab = :progress_graph
    render layout: @layout
  end

  # This call is used to dismiss the "not configured" box. "configured" means
  # that the client already setup one or more e-mails to receive the noitications
  def dismiss_alert_setup
    @project = get_project
    @project.translation_analytics_profile.update_attribute :configured, true

    render layout: false
  end

  private

  def setup_progress_graph_data(project, language_pair = nil)
    progress_graph_data = {
      translated: [],
      untranslated: [],
      dates: [],
      deadlines: [],
      deadline_pair_id: [],
      deadline_target_language: [],
      today: []
    }

    snapshots = project.translation_analytics_language_pairs.map(&:translation_snapshots).flatten
    snapshot_languages = project.translation_analytics_language_pairs.to_set
    grouped_snapshots = snapshots.group_by { |ts| ts.date.strftime('%Y/%m/%d') }.find_all { |x| x[0].to_date <= Date.today }

    languages_last_data = Hash.new
    last_date = nil

    grouped_snapshots.each do |date, snpts|
      # Fill the empty space from the graph.
      # When there is a snapshot from one day missing,
      # we use the last available data for that day.
      if last_date && (last_date + 1.day).to_date < date.to_date
        progress_graph_data[:translated] << progress_graph_data[:translated].last
        progress_graph_data[:untranslated] << progress_graph_data[:untranslated].last
        progress_graph_data[:deadlines] << nil
        progress_graph_data[:deadline_pair_id] << nil
        progress_graph_data[:deadline_target_language] << nil
        date_with_no_data = last_date + 1.day
        progress_graph_data[:dates] << date_with_no_data
        progress_graph_data[:today] << (Date.today == date_with_no_data.to_date)
        last_date = date_with_no_data
        redo

      # Fill the date with the data gathered
      else
        last_date = date.to_date
        progress_graph_data[:dates] << date
        progress_graph_data[:today] << (Date.today == date.to_date)

        # Data from that day for one language pair only
        if language_pair
          progress_graph_data[:deadlines] << (language_pair.deadline.to_date == date.to_date)
          progress_graph_data[:deadline_pair_id] << language_pair.id
          progress_graph_data[:deadline_target_language] <<  nil
          snapshot = (language_pair.translation_snapshots & snpts).last
          if snapshot
            progress_graph_data[:untranslated] << snapshot.words_to_translate
            progress_graph_data[:translated] << snapshot.translated_words
          end

        # Data from that day for all language pairs
        else
          deadlines_pairs = {}
          untranslated = 0
          translated = 0
          languages_checked = Set.new
          snpts.each do |s|
            deadlines_pairs[s.language_pair.deadline.to_date] = s.language_pair
            deadline = s.language_pair.deadline.to_date
            untranslated += s.words_to_translate
            translated += s.translated_words
            languages_checked << s.language_pair
            languages_last_data[s.language_pair] = {
              untranslated: untranslated,
              translated: translated
            }

          end
          deadlines = deadlines_pairs.keys

          # Include languages that missed a snapshot with lastest data,
          # this way all language arrays have the same size.
          (snapshot_languages - languages_checked).each do |missing_language|
            translated += languages_last_data[missing_language][:translated] unless languages_last_data[missing_language].nil?
            untranslated += languages_last_data[missing_language][:untranslated] unless languages_last_data[missing_language].nil?
          end

          # Add vertical markers for deadlines. This is used only on the progress graph
          progress_graph_data[:translated] << translated
          progress_graph_data[:untranslated] << untranslated
          if deadlines.include?(date)
            progress_graph_data[:deadlines] << true
            progress_graph_data[:deadline_pair_id] << deadlines_pairs[date].id
            progress_graph_data[:deadline_target_language] << deadlines_pairs[date].to_language.name
          else
            progress_graph_data[:deadlines] << false
            progress_graph_data[:deadline_pair_id] << nil
            progress_graph_data[:deadline_target_language] << nil
          end
        end
      end
    end

    # Draw the graph up to last important date (current date or deadline),
    # even if there is no new data.
    deadlines_pairs = {}
    if language_pair
      deadlines = [language_pair.deadline.to_date]
      deadlines_pairs[language_pair.deadline.to_date] = language_pair
    else
      snapshots.each do |s|
        deadlines_pairs[s.language_pair.deadline.to_date] = s.language_pair
      end
      deadlines = deadlines_pairs.keys
    end

    last_important_date = (deadlines + [Date.today]).max + 1

    last_date.upto(last_important_date) do |date|
      next unless last_date != date
      if last_date <= Date.today
        progress_graph_data[:translated] << progress_graph_data[:translated].last
      end
      progress_graph_data[:untranslated] << progress_graph_data[:untranslated].last

      if deadlines.include?(date)
        progress_graph_data[:deadlines] << true
        progress_graph_data[:deadline_pair_id] << deadlines_pairs[date].id
        progress_graph_data[:deadline_target_language] << deadlines_pairs[date].to_language.name
      else
        progress_graph_data[:deadlines] << false
        progress_graph_data[:deadline_pair_id] << nil
        progress_graph_data[:deadline_target_language] << nil
      end

      date_with_no_data = last_date + 1.day
      progress_graph_data[:dates] << date_with_no_data
      progress_graph_data[:today] << (Date.today == date_with_no_data.to_date)
      last_date = date_with_no_data
    end

    [:translated, :untranslated, :dates, :deadlines, :deadline_pair_id, :deadline_target_language, :today].each do |index|
      progress_graph_data[index] = progress_graph_data[index].last(MAX_SNAPSHOTS) if progress_graph_data[index].size > MAX_SNAPSHOTS
    end

    progress_graph_data
  end

  def setup_overview_languages_data(project)
    bars_data = {
      translated: [],
      untranslated: [],
      language_pairs: []
    }
    language_pairs = project.translation_analytics_language_pairs

    language_pairs.each do |language_pair|
      bars_data[:language_pairs] << { from: language_pair.from_language.name, to: language_pair.to_language.name }
      last_snapshot = language_pair.translation_snapshots.last
      translated_words = last_snapshot.try(:translated_words) || 0
      words_to_translate = last_snapshot.try(:words_to_translate) || 0
      bars_data[:untranslated] << words_to_translate - translated_words
      bars_data[:translated] << translated_words
    end

    bars_data
  end
end
