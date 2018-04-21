class CreateDocuments < ActiveRecord::Migration
	def self.up
		create_table(:documents, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :type, :string	# there may be different types of documents
			t.column :title, :string
			t.column :body, :text
			t.column :encoding, :string
			t.column :chgtime, :datetime
			t.column :owner_id, :int
			t.column :owner_type, :string		
		end
	end

	def self.down
		drop_table :documents
	end
end
