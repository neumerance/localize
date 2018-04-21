module Users
  class WebsiteTranslationInvite < InviteToJob
    def find_job
      @job = WebsiteTranslation.find_by(id: job_id)
    end

    def send_invite
      website_translation_contract = job.website_translation_contracts.where('translator_id=?', @auser.id).first

      if website_translation_contract
        @problem = _('Translator already invited')
      else
        website_translation_contract = WebsiteTranslationContract.new(status: TRANSLATION_CONTRACT_NOT_REQUESTED, currency_id: DEFAULT_CURRENCY_ID)
        website_translation_contract.website_translation_offer = job
        website_translation_contract.translator = @auser
        website_translation_contract.save

        message = Message.new(body: message, chgtime: Time.now)
        message.user = @user
        message.owner = website_translation_contract
        message.save!

        @auser.create_reminder(EVENT_NEW_WEBSITE_TRANSLATION_MESSAGE, website_translation_contract)
        if @auser.can_receive_emails?
          ReminderMailer.new_message_for_cms_translation(@auser, website_translation_contract, message).deliver_now
        end

        @redirect = { controller: :website_translation_contracts, action: :show, id: website_translation_contract.id, website_translation_offer_id: job.id, website_id: job.website.id }
      end
    end

    def permissions_ok?
      @user.can_modify?(job.website)
    end
  end
end
