class CreateTestimonials < ActiveRecord::Migration[5.0]
  def up
    create_table :testimonials do |t|
      t.text :testimonial, null: false
      t.string :link_to_app
      t.string :testimonial_by, null: false
      t.integer :owner_id
      t.string :owner_type
      t.integer :rating, default: 0
      t.timestamps
    end
  end

  def down
    drop_table :testimonials
  end
end
