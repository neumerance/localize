module WebsiteTranslationContractsHelper

  include WebsiteTranslationOffersHelper

  def display_pending_work(website_translation_offer)
    docs_count, word_count = website_translation_offer.open_work_stats
    if docs_count == 0
      return _('No documents pending translation in this language pair.')
    else
      return _('%d document(s) with %d words pending translation in this language pair.') % [docs_count, word_count]
    end
  end
end
