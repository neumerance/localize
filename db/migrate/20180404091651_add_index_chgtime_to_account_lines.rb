class AddIndexChgtimeToAccountLines < ActiveRecord::Migration[5.0]
  def up
    add_index :account_lines, :chgtime, name: 'by_chgtime', algorithm: :inplace
  end

  def down
    remove_index :account_lines, name: 'by_chgtime'
  end
end
