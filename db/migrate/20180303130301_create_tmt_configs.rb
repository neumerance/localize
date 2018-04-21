class CreateTmtConfigs < ActiveRecord::Migration[5.0]
  def up
    create_table :tmt_configs do |t|
      t.integer :cms_request_id
      t.integer :translator_id
      t.boolean :enabled, default: false
      t.timestamps
    end
  end

  def down
    drop_table :tmt_configs
  end
end
