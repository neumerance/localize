class RemovePayPerUseFromWebsiteTranslationOffer < ActiveRecord::Migration[5.0]
  def change
    remove_column :website_translation_offers, :pay_per_use, :string
  end
end
