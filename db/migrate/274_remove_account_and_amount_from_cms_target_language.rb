class RemoveAccountAndAmountFromCmsTargetLanguage < ActiveRecord::Migration
	def self.up
		remove_column :cms_target_languages, :amount
	end

	def self.down
		add_column :cms_target_languages, :amount, :decimal, {:precision=>8, :scale=>2, :default=>0}
	end
end
