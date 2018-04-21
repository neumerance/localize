class AddNotesToSupportTickets < ActiveRecord::Migration
  def self.up
    add_column :support_tickets, :note, :text
  end

  def self.down
    remove_column :support_tickets, :note
  end
end