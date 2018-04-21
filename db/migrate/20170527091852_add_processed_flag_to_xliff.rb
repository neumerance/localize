class AddProcessedFlagToXliff < ActiveRecord::Migration[5.0]

  def self.up
    add_column :xliffs, :processed, :boolean, default: false
  end

  def self.down
    remove_column :xliffs, :processed
  end
end
