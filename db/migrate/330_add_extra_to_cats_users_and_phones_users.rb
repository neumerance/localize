class AddExtraToCatsUsersAndPhonesUsers < ActiveRecord::Migration
	def self.up
		add_column :cats_users, :extra, :text
		add_column :phones_users, :extra, :text

		Cat.create(:name => "Others")
		Phone.create(:name => "Others")
	end

	def self.down
		remove_column :cats_users, :extra
		remove_column :phones_users, :extra

		Cat.delete_all "name = 'Others'"
		Phone.delete_all "name = 'Others'"

	end
end
