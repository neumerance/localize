# Load the Rails application.
require_relative 'application'

# Initialize the Rails application.
Rails.application.initialize!
Profiling::IclMemoryProfiler.setup
Profiling::IclMemoryProfiler.start
