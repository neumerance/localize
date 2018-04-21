ImportJob = Struct.new(:xliff, :flag) do

  def perform
    ParsedXliff.create_parsed_xliff(xliff, flag)
  end

  def destroy_failed_jobs?
    false
  end

  def max_attempts
    1
  end

  def max_run_time
    900 # seconds
  end

  def queue_name
    'tm_import'
  end

end
