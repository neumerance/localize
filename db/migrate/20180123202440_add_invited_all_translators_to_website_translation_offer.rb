class AddInvitedAllTranslatorsToWebsiteTranslationOffer < ActiveRecord::Migration[5.0]
  def change
    add_column :website_translation_offers, :invited_all_translators, :boolean
  end
end
