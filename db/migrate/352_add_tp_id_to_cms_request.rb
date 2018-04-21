class AddTpIdToCmsRequest < ActiveRecord::Migration
  def self.up
    add_column :cms_requests, :tp_id, :integer
  end

  def self.down
    remove_column :cms_requests, :tp_id
  end
end
