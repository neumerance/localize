class AddSessions < ActiveRecord::Migration
  def self.up
    create_table(:sessions, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
      t.column :session_id, :string
      t.column :data, :mediumtext
      t.column :updated_at, :datetime
    end

    add_index :sessions, :session_id
    add_index :sessions, :updated_at
  end

  def self.down
    drop_table :sessions
  end
end
