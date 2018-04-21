class CreateUserSessions < ActiveRecord::Migration
  def self.up
    create_table(:user_sessions, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
      t.column :user_id, :int
      t.column :session_num, :string
      t.column :login_time, :datetime
      t.column :embedded, :int
    end
	add_index :user_sessions, [:session_num], :name=>'session_num', :unique => true
  end

  def self.down
    drop_table :user_sessions
  end
end
