class UpdateTmUseToMinimumTreshold < ActiveRecord::Migration[5.0]
  def self.up
    Website.where('tm_use_threshold < 2').update_all(tm_use_threshold: 2)
  end

  def self.down
    # can't revert this change
  end
end
