class AddPaymentFlag < ActiveRecord::Migration
	def self.up
		add_column :string_translations, :pay_translator, :integer, :default=>0
	end

	def self.down
		remove_column :string_translations, :pay_translator
	end
end
