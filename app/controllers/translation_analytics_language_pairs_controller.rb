class TranslationAnalyticsLanguagePairsController < ApplicationController
  prepend_before_action :setup_user

  def edit_deadlines

    language_pair = TranslationAnalyticsLanguagePair.find(params[:language_pair_id])
    unless Website.find(params[:project_id]).translation_analytics_profile.translation_analytics_language_pairs.include?(language_pair)
      raise 'Not your pair'
    end

    @language_pairs = [language_pair]

    @deadline_manual = @language_pairs.find { |lp| !lp.auto_deadline? }
    @deadline_date = @language_pairs.map(&:deadline).min

  rescue => e
    @error = e.message

  end

  private

  def get_languages
    params[:language_pairs] ||= []
    params[:language_pairs].delete('null')
    language_pairs = TranslationAnalyticsLanguagePair.find(params[:language_pairs])
    if language_pairs.empty?
      raise 'You need to select at least one language pair to do this!'
    end
    language_pairs
  end
end
