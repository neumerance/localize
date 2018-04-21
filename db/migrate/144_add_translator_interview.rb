class AddTranslatorInterview < ActiveRecord::Migration
	def self.up
		add_column :website_translation_offers, :interview_translators, :integer, :default=>1
	end

	def self.down
		remove_column :website_translation_offers, :interview_translators
	end
end
