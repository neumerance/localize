class AnalyticsController < ApplicationController
  prepend_before_action :setup_user
  layout :determine_layout

  def index
    @header = _('Translation analytics')

    website_ids = @user.websites.collect(&:id)
    @cms_count_group = CmsCountGroup.where('website_id IN (?)', website_ids).order('cms_count_groups.id DESC')
    kind = params[:kind].to_i

    if @cms_count_group

      @cms_counts = @cms_count_group.cms_counts.where(kind: kind).includes(:website_translation_offer)

      # collect the different attributes we can filter according
      # compile the language pairs
      unsorted_offers = []
      @websites = []
      @priorities = []
      @codes = []
      @services = []
      @cms_counts.each do |cms_count|
        unless unsorted_offers.include?(cms_count.website_translation_offer)
          unsorted_offers << cms_count.website_translation_offer
          unless @websites.include?(cms_count.cms_count.website_translation_offer.websites)
            @websites << cms_count.cms_count.website_translation_offer.websites
          end
        end
        unless @priorities.include?(cms_count.priority)
          @priorities << cms_count.priority
        end
        if cms_count.code && !@codes.include?(cms_count.code)
          @codes << cms_count.code
        end
        if cms_count.service && !@services.include?(cms_count.service)
          @services << cms_count.service
        end
      end

      # sort the results
      language_pairs = []
      unsorted_offers.each do |website_translation_offer|
        language_pairs << ["#{website_translation_offer.from_language.name}-#{website_translation_offer.to_language.name}", website_translation_offer]
      end
      language_pairs.sort

      @website_translation_offers = language_pairs.collect { |lp| lp[1] }

      # now, compile the translation completeness data from all the fragments
    end

  end

end
