# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# Example:
#
# set :output, "/path/to/my/cron_log.log"
#
# every 2.hours do
#   command "/usr/bin/some_great_command"
#   runner "MyModel.some_method"
#   rake "some:great:rake:task"
# end
#
# every 4.days do
#   runner "AnotherModel.prune_old_records"
# end

# Learn more: http://github.com/javan/whenever

set :output, '~/rails_apps/icanlocalize/shared/log/cron_log.log'

# Be careful with what you include here, it may take a lot of server resources
every 10.minutes do
  runner 'script/cron_jobs/run_every_ten_minutes.rb'
end

every 1.hour do
  runner 'script/cron_jobs/run_hourly.rb'
end

every 1.day, at: '2:40 am' do
  runner 'script/cron_jobs/run_periodic.rb'
end
