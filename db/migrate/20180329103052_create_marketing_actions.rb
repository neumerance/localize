class CreateMarketingActions < ActiveRecord::Migration[5.0]
  def change
    create_table :marketing_actions do |t|
      t.references :project, polymorphic: true, index: true
      t.integer :action
      t.integer :subject
      t.datetime :performed_at
    end
  end
end
