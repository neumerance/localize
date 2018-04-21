module StaleObjHandler

  def retry(retries = 5)
    @staled_retries ||= retries
    yield
  rescue ActiveRecord::StaleObjectError => e
    if @staled_retries.zero?
      Rails.logger.error ' Staled object retried 5 times, raising error.'
      raise e
    end

    Rails.logger.error " Staled Object Error for #{e.record} retrying..."
    e.record.reload
    @staled_retries -= 1
    retry
  end
  module_function :retry
end
