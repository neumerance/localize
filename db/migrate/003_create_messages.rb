class CreateMessages < ActiveRecord::Migration
  def self.up
    create_table(:messages, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
      # who holds this message (chat or arbitration)
	  t.column :owner_id, :int
      t.column :owner_type, :string
	  
      # common attributes for base class
      t.column :user_id, :int		# user who posted the message
      t.column :body, :text		# body of the message
      t.column :chgtime, :datetime	# posting time

    end
  end

  def self.down
    drop_table :messages
  end
end
