class AddSendAdminNotificationsToUser < ActiveRecord::Migration
  def self.up
    User.reset_column_information
    add_column(:users, :send_admin_notifications, :boolean) unless User.column_names.include?('send_admin_notifications')
  end

  def self.down
    User.reset_column_information
    remove_column(:users, :send_admin_notifications) if User.column_names.include?('send_admin_notifications')
  end
end
