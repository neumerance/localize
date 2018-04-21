class MandrillController < ApplicationController
  def bounce
    if params[:mandrill_events]
      mandrill_events = JSON.parse(params[:mandrill_events])
      events = mandrill_events.find_all { |event| %w(hard_bounce spam soft_bounce reject).include? event['event'] }
      emails = events.map { |event| event['msg']['email'] }

      logger.warn "Blacklisting emails: #{emails}"

      models = []
      models += User.where(email: emails)
      models += WebDialog.where(email: emails)
      models += AlertEmail.where(email: emails)
      models.delete_if(&:nil?)
      models.each { |model| model.update_attribute :bounced, true }
    end

    render nothing: true
  end
end
