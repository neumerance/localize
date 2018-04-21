class HelpPlacement < ApplicationRecord
  include Rails.application.routes.url_helpers

  belongs_to :help_topic
  belongs_to :help_group
  attr_accessor :url

  validates :url, presence: true, url_field: true
  validate :action_and_controller_presence
  before_validation :dec_url

  def get_path(host)
    url_for(controller: controller, action: action, host: host) unless controller.nil?
  end

  def action_and_controller_presence
    self.errors[:url] = 'path is required' if controller.nil? || controller.blank?
  end

  def dec_url
    unless self.url.nil? || self.url.blank?
      idx = self.url.index('/', 8)
      return nil unless idx
      begin
        path = Rails.application.routes.recognize_path(url[idx..-1])
        path[:action] = 'show' if path[:action].to_i > 0
        self.action = path[:action]
        self.controller = path[:controller]
      rescue StandardError => e
        self.errors[:base] = e.message
      end
    end
  end

end
