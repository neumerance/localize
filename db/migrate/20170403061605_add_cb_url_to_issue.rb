class AddCbUrlToIssue < ActiveRecord::Migration[5.0]

  def self.up
    add_column :issues, :tp_callback_url, :string, default: nil
  end

  def self.down
    remove_conlumn :issues, :tp_callback_url
  end
end
