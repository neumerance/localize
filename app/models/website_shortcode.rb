#   This model handle configuration for global shortcodes, currently it only
#   allows to enable/disable a global shortcode
class WebsiteShortcode < ApplicationRecord
  belongs_to :website
  belongs_to :shortcode

  scope :enabled, -> { where(enabled: true) }
  scope :disabled, -> { where(enabled: false) }

  def enabled?
    enabled
  end

  def toggle_enabled
    # @ToDo we could destroy the record if request is to disable.
    self.enabled = id ? !enabled : !shortcode.enabled?
    save
  end
end
