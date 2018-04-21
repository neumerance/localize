class CreateWebMessages < ActiveRecord::Migration
	def self.up
		create_table( :web_messages, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			# enable optimistic locking
			t.column :lock_version, :int, :default => 0
			
			# languages
			t.column :visitor_language_id, :int
			t.column :client_language_id, :int
			
			# who holds this message (web dialog)
			t.column :owner_id, :int
			t.column :owner_type, :string

			t.column :user_id, :int					# user who posted the message
			t.column :visitor_body, :text			# body of the message
			t.column :client_body, :text			# body of the message

			t.column :create_time, :datetime
			t.column :translate_time, :datetime
			
			t.column :word_count, :int				# number of words in the job
			t.column :money_account_id, :int		# if the project can be funded, the account to fund from (for quick balance check)
			
			# translation status
			t.column :translator_id, :int
			t.column :translation_status, :int, :default=>0
		end
	end

	def self.down
		drop_table :web_messages
	end
end
