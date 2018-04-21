class AddTranslatorRating < ActiveRecord::Migration
	def self.up
		add_column :users, :rating, :decimal, {:precision=>8, :scale=>2, :default=>0}
		add_index :users, [:rating], :name=>'rating', :unique=>false
	end

	def self.down
		remove_column :users, :rating
	end
end
