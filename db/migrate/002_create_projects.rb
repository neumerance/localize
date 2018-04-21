class CreateProjects < ActiveRecord::Migration
  def self.up
    create_table(:projects, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
      t.column :name, :string
      t.column :client_id, :int
    end
  end

  def self.down
    drop_table :projects
  end
end
