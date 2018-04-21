class AddLastPaymentDateToWebsiteTranslationOffer < ActiveRecord::Migration[5.0]
  def change
    add_column :website_translation_offers, :last_payment_date, :datetime
  end
end
