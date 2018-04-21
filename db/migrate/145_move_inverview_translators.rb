class MoveInverviewTranslators < ActiveRecord::Migration
	def self.up
		remove_column :website_translation_offers, :interview_translators
		add_column :websites, :interview_translators, :integer, :default=>1
	end

	def self.down
		add_column :website_translation_offers, :interview_translators, :integer, :default=>1
		remove_column :websites, :interview_translators
	end
end
