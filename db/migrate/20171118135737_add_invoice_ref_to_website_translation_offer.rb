class AddInvoiceRefToWebsiteTranslationOffer < ActiveRecord::Migration[5.0]
  def change
    add_reference :website_translation_offers, :invoice, foreign_key: true
  end
end
