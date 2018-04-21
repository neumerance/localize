class AddSessionTrackIndex < ActiveRecord::Migration
	def self.up
		add_index :session_tracks, [:type, :resource_id, :user_session_id], :name=>'all_values', :unique => true
	end

	def self.down
		remove_index :session_tracks, :name=>'all_values'
	end
end
