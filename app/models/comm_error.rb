class CommError < ApplicationRecord
  belongs_to :cms_request

  before_save :truncate_col

  STATUS_TEXT = { COMM_ERROR_CLOSED => N_('Closed'), COMM_ERROR_ACTIVE => N_('Active') }.freeze

  ERROR_KIND_TEXT = {
    COMM_ERROR_FAILED_TO_CREATED_PROJECT => N_('Failed to create translation project'),
    COMM_ERROR_FAILED_TO_RETURN_TRANSLATION => N_('Failed to return translation to website'),
    COMM_ERROR_HTML_PARSE_ERROR => N_('Error parsing HTML document')
  }.freeze

  def close
    update_attribute :status, COMM_ERROR_CLOSED
  end

  def truncate_col
    col_size = CommError.columns_hash['error_report'].limit
    self.error_report = self.error_report.truncate(col_size) if self.error_report
  end

end
