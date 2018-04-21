class AdminController < ApplicationController
  def clear_db
    if (Rails.env == 'development') || (Rails.env == 'sandbox')
      Project.destroy_all
      Revision.destroy_all
      ::Version.destroy_all
      SupportFile.destroy_all
      Chat.destroy_all
      Message.destroy_all
      Attachment.destroy_all
      Bid.destroy_all
      RevisionLanguage.destroy_all
      Reminder.destroy_all
      ArchiveTag.destroy_all
      Bookmark.destroy_all
      RevisionCategory.destroy_all
      SessionTrack.destroy_all
      AccountLine.destroy_all
      MoneyTransaction.destroy_all
      Arbitration.destroy_all
      ArbitrationOffer.destroy_all
      Invoice.destroy_all
      MoneyTransaction.destroy_all
      @result = 'OK'
    else
      set_err("Can't do")
    end
  end
end
