if PROFILER_ENABLED
  require 'rack-mini-profiler'
  # initialization is skipped so trigger it
  Rack::MiniProfilerRails.initialize!(Rails.application)
end
