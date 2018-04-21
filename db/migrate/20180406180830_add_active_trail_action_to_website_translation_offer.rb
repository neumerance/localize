class AddActiveTrailActionToWebsiteTranslationOffer < ActiveRecord::Migration[5.0]
  def change
    add_reference :website_translation_offers, :active_trail_action, foreign_key: true
  end
end
