class AddTranslationAmountToResourceLanguage < ActiveRecord::Migration
	def self.up
		add_column :resource_languages, :translation_amount, :decimal, {:precision=>8, :scale=>2, :default=>INSTANT_TRANSLATION_COST_PER_WORD}
	end

	def self.down
		remove_column :resource_languages, :translation_amount
	end
end
