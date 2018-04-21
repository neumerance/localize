class AddBouncedToAlertEmails < ActiveRecord::Migration
  def self.up
    add_column :alert_emails, :bounced, :boolean, :default => false
  end

  def self.down
    remove_column :alert_emails, :bounced
  end
end
