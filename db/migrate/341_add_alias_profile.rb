class AddAliasProfile < ActiveRecord::Migration
	def self.up
		create_table(:alias_profiles, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :user_id, :integer

			## Projects access
			t.column :project_access_mode, :integer, :default => 0

			# Access to all projects
			t.column :project_view, :boolean, :default => false
			t.column :project_modify, :boolean, :default => false
			t.column :project_create, :boolean, :default => false

			# Access to projects list
			t.column :project_list, :text
			t.column :website_list, :text
			t.column :text_resource_list, :text
			t.column :web_message_list, :text

			## Finance access
			t.column :financial_view, :boolean, :default => false
			t.column :financial_deposit, :boolean, :default => false
			t.column :financial_pay, :boolean, :default => false
		end
	end

	def self.down
		drop_table :alias_profiles
	end
end
