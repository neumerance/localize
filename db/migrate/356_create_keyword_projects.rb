class CreateKeywordProjects < ActiveRecord::Migration
  def self.up
    create_table(:keyword_projects, :option => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
      # resource language/revision language/translation offer that the keyword project belongs to
      t.column :owner_id, :integer, :null => false
      t.column :owner_type, :string, :null => false
      t.column :status, :integer, :null => false, :default => 0
      t.column :comments, :text
      t.timestamps
    end
  end

  def self.down
    drop_table :keyword_projects
  end
end
