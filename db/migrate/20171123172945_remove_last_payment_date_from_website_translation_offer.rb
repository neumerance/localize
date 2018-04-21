class RemoveLastPaymentDateFromWebsiteTranslationOffer < ActiveRecord::Migration[5.0]
  def change
    remove_column :website_translation_offers, :last_payment_date, :string
  end
end
