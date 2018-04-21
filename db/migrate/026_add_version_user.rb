class AddVersionUser < ActiveRecord::Migration
	def self.up
		add_column :zipped_files, :by_user_id, :integer
	end

	def self.down
		remove_column :zipped_files, :by_user_id
	end
end
