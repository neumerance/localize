require 'base64'
require 'cgi'

module CmsActions
  module Notifications
    class AlertSupportersAboutBase64

      def call(cms_request)
        base64_regex = /<!\[CDATA\[[a-zA-Z0-9]{30,}\=*\]\]*/
        xliff_content = cms_request.base_xliff.get_contents
        ReminderMailer.job_has_base64_content(cms_request).deliver if !!(xliff_content =~ base64_regex)
      end

    end
  end
end
