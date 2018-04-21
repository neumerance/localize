class ChangeFeedbackToPublic < ActiveRecord::Migration
	def self.up
		remove_column :feedbacks, :client_id
		remove_column :feedbacks, :company
		remove_column :feedbacks, :title
		remove_column :feedbacks, :url
		remove_column :feedbacks, :showall
		
		add_column :feedbacks, :translator_id, :integer
		add_column :feedbacks, :from_language_id, :integer
		add_column :feedbacks, :to_language_id, :integer
		add_column :feedbacks, :rating, :integer
		add_column :feedbacks, :source, :string
		add_column :feedbacks, :name, :string
		add_column :feedbacks, :email, :string
		
		add_index :feedbacks, [:owner_type, :owner_id], :name=>'owner', :unique=>false
		add_index :feedbacks, [:translator_id], :name=>'translator', :unique=>false
	end

	def self.down
		add_column :feedbacks, :client_id, :integer
		add_column :feedbacks, :company, :string
		add_column :feedbacks, :title, :string
		add_column :feedbacks, :url, :string
		add_column :feedbacks, :showall, :integer
		
		remove_index :feedbacks, :name=>'owner'
		remove_index :feedbacks, :name=>'translator'
		
		remove_column :feedbacks, :translator_id
		remove_column :feedbacks, :from_language_id
		remove_column :feedbacks, :to_language_id
		remove_column :feedbacks, :rating
		remove_column :feedbacks, :source
		remove_column :feedbacks, :name
		remove_column :feedbacks, :email
		
	end
end
