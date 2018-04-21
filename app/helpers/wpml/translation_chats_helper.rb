module Wpml::TranslationChatsHelper
  # Chat with translators whose bids were accepted for a given language pair
  # language_pair should be a WebsiteTranslationOffer record
  def accepted_translator_names_and_chat_links(language_pair, display_chat_link = true, separated_by_br = false)
    translator_links = language_pair.translators_accepted.map do |translator|
      wtc = language_pair.website_translation_contracts.where(translator: translator).first
      translator_profile_path = link_to(translator.nickname,
                                        user_path(translator),
                                        target: '_blank')
      # If it's a private translator, let the user know
      private_translator_text = translator.private_translator? ? '(private translator)' : ''

      if display_chat_link
        translator_chat_link = link_to(
          'chat',
          website_website_translation_offer_website_translation_contract_path(language_pair.website, language_pair, wtc),
          target: '_blank'
        )
        "#{translator_profile_path} #{private_translator_text} (#{translator_chat_link})"
      else
        "#{translator_profile_path} #{private_translator_text}"
      end
    end
    if separated_by_br
      translator_links.join('<br>').html_safe
    else
      translator_links.to_sentence.html_safe
    end
  end

  # Display the name of the reviewer and a link to his profile.
  #
  # - For language pairs with automatic translator assignment, a reviewer is
  #   assigned per language pair and persisted in
  #   website_translation_offer.managed_work.translator
  #
  # - For language pairs with manual translator assignment, any translator can
  #   see the websites and language pairs they are qualified to review in the
  #   "Available review jobs" section of the "/translator/open_work" page.
  #   If the translator clicks "Become the reviewer for this job", he gets the
  #   job (without the need for the client's acceptance). Then the Translator
  #   record is associated with the MW as
  #   website_translation_offer.managed_work.translator.
  def reviewer_name_and_profile_link(language_pair)
    reviewer = language_pair&.managed_work&.translator
    return 'No reviewer assigned' unless reviewer.present?

    reviewer_profile_link = link_to(reviewer.nickname,
                                    user_path(reviewer),
                                    target: '_blank')

    # Currently there is no way to chat with a reviewer because there are only
    # 2 types of chats in ICL, one per revision (per cms_request, we need per
    # language pair) and another by WebsiteTranslationContract (which reviewers
    # do not have).
    # reviewer_chat_link = link_to(
    #   'chat',
    #   website_website_translation_offer_website_translation_contract_path(language_pair.website, language_pair, wtc),
    #   target: '_blank'
    # )

    "Reviewer assigned: #{reviewer_profile_link}".html_safe
  end
end
