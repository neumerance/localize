class CreateRevisions < ActiveRecord::Migration
  def self.up
    create_table(:revisions, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
      t.column :project_id, :int
	  
      t.column :description, :text
      t.column :language_id, :int
	  
      t.column :name, :string
      t.column :released, :int

      # revision statistics
      t.column :word_count, :int

      # bid limitations
      t.column :max_bid, :decimal, {:precision=>8, :scale=>2, :default=>0}
      t.column :max_bid_currency, :int

      # project schedule
      t.column :bidding_duration, :int				# in days
      t.column :project_completion_duration, :int	# in days

    end
  end

  def self.down
    drop_table :revisions
  end
end
