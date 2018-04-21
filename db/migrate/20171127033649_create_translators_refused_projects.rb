class CreateTranslatorsRefusedProjects < ActiveRecord::Migration[5.0]
  def up
    create_table :translators_refused_projects do |t|
      t.integer :translator_id, null: false
      t.references :owner, polymorphic: true, index: true
      t.text :remarks
      t.string :project_type, null: false
      t.timestamps
    end
  end

  def down
    drop_table :translators_refused_projects
  end
end
