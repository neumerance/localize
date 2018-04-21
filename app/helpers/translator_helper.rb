module TranslatorHelper
  def display_pending_work(website_translation_offer)
    docs_count, word_count = website_translation_offer.open_work_stats
    if docs_count == 0
      return '<span class="comment">None yet</span>'
    else
      return _('%d document(s) with %d words') % [docs_count, word_count]
    end
  end

  def display_cms_request(cms_request, enabled)
    content_tag(:span) do
      if enabled || %w(sandbox development).include?(Rails.env)
        concat content_tag(:span, 'DEBUG', class: 'comment') unless enabled
        concat link_to((_('%s &raquo; %s') % [cms_request.website.name, h(cms_request.title)]).html_safe, controller: :cms_requests, action: :show, website_id: cms_request.website_id, id: cms_request.id)
      else
        concat content_tag(:span, (_('%s &raquo; %s') % [cms_request.website.name, cms_request.title]).html_safe, class: 'comment')
      end

      if cms_request.cms_target_languages.length == 1
        ctl = cms_request.cms_target_languages[0]
        concat ' '.html_safe + cms_request.language.name
        concat ' '.html_safe + _('to')
        concat ' '.html_safe + ctl.language.name; concat ' '.html_safe
        concat content_tag(:strong, ctl.word_count) if ctl.word_count
      end
    end
  end

  # This method does not use caching as it does not generate N+1 (the query
  # includes everything this method needs)
  def open_managed_work_link(review)
    content_tag(:span) do
      if review.owner_type == 'ResourceLanguage'
        link_to(controller: :text_resources, action: :show, id: review.id_for_link) do
          concat 'Software localization project - '
          concat content_tag(:b, review.project_name)
          concat ' - '
          concat content_tag(:b, review.from_language_name)
          concat ' to '
          concat content_tag(:b, review.to_language_name)
        end
      elsif review.owner_type == 'RevisionLanguage'
        link_to(controller: :revisions, action: :show, id: review.revision_language_revision_id, project_id: review.id_for_link) do
          # This is a bidding project, NOT a Website Translation project
          concat 'Project - '
          concat content_tag(:b, review.project_name)
          concat ' - '
          concat content_tag(:b, review.from_language_name)
          concat ' to '
          concat content_tag(:b, review.to_language_name)
        end
      elsif review.owner_type == 'WebsiteTranslationOffer'
        link_to(controller: :website_translation_offers, action: :review, website_id: review.wto_website_id, id: review.id_for_link) do
          concat 'WPML Website - '
          concat content_tag(:b, review.project_name)
          concat ' - '
          concat content_tag(:b, review.from_language_name)
          concat ' to '
          concat content_tag(:b, review.to_language_name)
        end
      end
    end
  end
end
