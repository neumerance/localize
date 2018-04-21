class CreateSuperTranslators < ActiveRecord::Migration[5.0]
  def change
    create_table :super_translators do |t|
      t.string :email
    end
  end
end
