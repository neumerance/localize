class RemoveLanguageManager < ActiveRecord::Migration
  def self.up
    SentNotification.where("owner_type = ? ", "LanguageManagerApplication").delete_all
    SupportTicket.where("object_type = ? ", "LanguageManagerApplication").delete_all

    Message.where("owner_type = ? ", "LanguageManagerApplication").delete_all
    Reminder.where("owner_type = ? ", "LanguageManagerApplication").delete_all

    drop_table :language_managers
    drop_table :language_manager_applications
  end
end
