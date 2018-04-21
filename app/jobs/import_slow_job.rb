ImportSlowJob = Struct.new(:xliff, :flag) do

  def perform
    ParsedXliff.create_parsed_xliff(xliff, flag)
  end

  def max_attempts
    1
  end

  def max_run_time
    7200 # seconds
  end

  def queue_name
    'tm_slow_import'
  end

  def default_priority
    15
  end

end
