class CreateSessionTracks < ActiveRecord::Migration
	def self.up
		create_table(:session_tracks, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :type, :string
			t.column :resource_id, :int
			t.column :user_session_id, :int
		end
	end

	def self.down
		drop_table :session_tracks
	end
end
