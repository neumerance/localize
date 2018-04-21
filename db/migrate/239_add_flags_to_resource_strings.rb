class AddFlagsToResourceStrings < ActiveRecord::Migration
	def self.up
		add_column :string_translations, :review_status, :integer, :default=>REVIEW_NOT_NEEDED
		add_column :string_translations, :pay_reviewer, :integer, :default=>0
	end

	def self.down
		remove_column :string_translations, :review_status
		remove_column :string_translations, :pay_reviewer
	end
end
