class ChangeSubjectToText < ActiveRecord::Migration[5.0]
  def up
    change_column :support_tickets, :subject, :text
  end

  def down
    change_column :support_tickets, :subject, :string
  end
end
