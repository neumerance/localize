class AddIdToClicks < ActiveRecord::Migration
	def self.up
		add_column :user_clicks, :resource_id, :integer
		add_column :user_clicks, :url, :string
		add_column :user_clicks, :method, :string
	end

	def self.down
		remove_column :user_clicks, :resource_id
		remove_column :user_clicks, :url
		remove_column :user_clicks, :method
	end
end
