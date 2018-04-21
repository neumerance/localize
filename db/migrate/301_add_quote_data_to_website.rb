class AddQuoteDataToWebsite < ActiveRecord::Migration
	def self.up
		add_column :websites, :word_count, :integer
		add_column :websites, :wc_description, :text
	end

	def self.down
		remove_column :websites, :word_count
		remove_column :websites, :wc_description
	end
end
