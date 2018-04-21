class UserClick < ApplicationRecord
  require 'uri'

  belongs_to :user

  scope :errors, -> { where('error is not NULL') }

  def new_session?
    (controller == 'login') && (action == 'login')
  end

  def register_error(exception)
    backtrace = exception.backtrace.join("\n")
    self.error = "#{exception.class} (#{exception.message})"
    self.log = "#{log}\r\n#{backtrace}"
    save!
  end

  def only_application_trace
    log.each_line.select { |l| l.include? Rails.root.to_s }.join("\r\n").strip
  end

end
