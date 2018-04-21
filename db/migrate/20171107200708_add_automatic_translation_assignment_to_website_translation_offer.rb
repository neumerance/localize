class AddAutomaticTranslationAssignmentToWebsiteTranslationOffer < ActiveRecord::Migration[5.0]
  def change
    add_column :website_translation_offers,
               :automatic_translator_assignment,
               :boolean
    # Populate new attribute in preexisting records
    WebsiteTranslationOffer.update_all(automatic_translator_assignment: false)
  end
end
