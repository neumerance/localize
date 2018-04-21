class AddSizeRatioToStringTranslations < ActiveRecord::Migration
	def self.up
		add_column :string_translations, :size_ratio, :decimal, {:precision=>8, :scale=>2, :default=>nil}
	end

	def self.down
		remove_column :string_translations, :size_ratio
	end
end
