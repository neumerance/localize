class AddSqlFilterToNewsletters < ActiveRecord::Migration
	def self.up
		add_column :newsletters, :sql_filter, :string
	end

	def self.down
		remove_column :newsletters, :sql_filter
	end
end
