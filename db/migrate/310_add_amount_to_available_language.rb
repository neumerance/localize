class AddAmountToAvailableLanguage < ActiveRecord::Migration
	def self.up
		add_column :available_languages, :amount, :decimal, {:precision=>8, :scale=>2, :default=>INSTANT_TRANSLATION_COST_PER_WORD}
	end

	def self.down
		remove_column :available_languages, :amount
	end
end
