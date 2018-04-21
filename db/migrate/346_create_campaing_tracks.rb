class CreateCampaingTracks < ActiveRecord::Migration
  def self.up
    create_table :campaing_tracks do |t|
      t.integer :campaing_id
      t.string :project_type
      t.integer :project_id
      t.integer :from_language_id
      t.integer :to_language_id
      t.integer :state
      t.string :extra_info

      t.timestamps
    end
    add_index :campaing_tracks, [:campaing_id, :state], :name=>'campain_status_index', :unique => false
  end

  def self.down
    drop_table :campaing_tracks
    remove_index :campaing_tracks, :name => 'campaing_status_index'
  end
end
