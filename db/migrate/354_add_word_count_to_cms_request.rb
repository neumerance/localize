class AddWordCountToCmsRequest < ActiveRecord::Migration
  def self.up
    add_column :cms_requests, :word_count, :integer
  end

  def self.down
    remove_column :cms_requests, :word_count
  end
end
