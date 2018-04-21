class ErrorReport < ApplicationRecord
  validates_presence_of :body, :prog, :version, :os, :email
  validates_format_of :email, with: /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z/i
  validates :resolution, length: { maximum: COMMON_NOTE }

  belongs_to :supporter

  OPEN = 0
  BEING_HANDLED = 1
  CLOSED = 2

  ERROR_REPORT_STATUS = { ERROR_REPORT_NEW => N_('new error'),
                          ERROR_REPORT_IN_WORK => N_('error being worked on'),
                          ERROR_REPORT_RESOLVED => N_('error resolved') }.freeze

  before_save :truncate_col

  def truncate_col
    col_size = ErrorReport.columns_hash['body'].limit
    self.body = self.body.truncate(col_size) if self.body
  end

end
