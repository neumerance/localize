class CreateXliff < ActiveRecord::Migration
  def self.up
		create_table(:xliffs, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
		  t.column :content_type, :string
		  t.column :filename, :string
		  t.column :size, :integer
      t.column :cms_request_id, :integer
      t.column :translated, :boolean, :default => false
    end
  end

  def self.down
	  drop_table :xliffs
  end
end
