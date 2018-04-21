class AddLanguageIsoCodes < ActiveRecord::Migration

	def self.up
		add_column :languages, :iso, :string
		add_index :languages, [:iso], :name=>'iso', :unique=>true
	end

	def self.down
		remove_column :languages, :iso
	end

end