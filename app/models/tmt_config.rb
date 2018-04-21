class TmtConfig < ApplicationRecord
  belongs_to :cms_request
  belongs_to :translator

  def toggle_mt_config
    update_attributes(enabled: true)
  end
end
