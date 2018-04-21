class RemoveInvoiceFromWebsiteTranslationOffer < ActiveRecord::Migration[5.0]
  def change
    remove_reference :website_translation_offers, :invoice, foreign_key: true
  end
end
