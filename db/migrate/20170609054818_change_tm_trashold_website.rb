class ChangeTmTrasholdWebsite < ActiveRecord::Migration[5.0]
  def up
    change_column_default :websites, :tm_use_threshold, 3
  end

  def down
    change_column_default :websites, :tm_use_threshold, 5
  end
end
