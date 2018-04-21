# run daily at 2:40am
# open log file
start_time = Time.now

error_happened = false

tlog = "\n\n------- periodic #{Rails.env} starting at: #{start_time.strftime(TIME_FORMAT_STRING)} --------\n"

#  set up the periodic checker
checker = PeriodicChecker.new(start_time)

#  run all
tlog += 'revisions_open_to_bids_check: '
begin
  checker.revisions_open_to_bids_check
  tlog += "OK\n"
rescue => e
  tlog += "ERROR\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end
tlog += "Took #{checker.elapsed_time} seconds\n\n"

tlog += 'work_needs_to_end_check: '
begin
  checker.work_needs_to_end_check
  tlog += "OK\n"
rescue => e
  tlog += "ERROR\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end
tlog += "Took #{checker.elapsed_time} seconds\n\n"

tlog += 'clean_old_captchas: '
begin
  checker.clean_old_captchas
  tlog += "OK\n"
rescue => e
  tlog += "ERROR\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end
tlog += "Took #{checker.elapsed_time} seconds\n\n"

tlog += 'send translator account setup reminder emails: '
begin
  cnt = checker.account_setup_reminder
  tlog += "OK. Sent #{cnt} emails\n"
rescue => e
  tlog += "ERROR\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end
tlog += "Took #{checker.elapsed_time} seconds\n\n"

tlog += 'Send welcome messages to translators (account setup complete): '
begin
  cnt = checker.ready_translator_accounts
  tlog += "OK. Sent #{cnt} emails\n"
rescue => e
  tlog += "ERROR\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end
tlog += "Took #{checker.elapsed_time} seconds\n\n"

tlog += 'Delivering newsletter: '
begin
  cnt = checker.send_newsletters
  tlog += "OK. Delivered #{cnt} newsletters\n"
rescue => e
  tlog += "ERROR\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end
tlog += "Took #{checker.elapsed_time} seconds\n\n"

tlog += 'Check for projects with no communication between translators and clients: '
begin
  cnt = checker.check_for_projects_with_no_progress
  tlog += "OK. #{cnt} warnings sent\n"
rescue => e
  tlog += "ERROR\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end
tlog += "Took #{checker.elapsed_time} seconds\n\n"

tlog += 'Remind about CMS projects: '
begin
  cnt = checker.remind_about_cms_projects
  tlog += "OK. #{cnt} reminders sent\n"
rescue => e
  tlog += "ERROR\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end
tlog += "Took #{checker.elapsed_time} seconds\n\n"

tlog += 'Apologize about old Instant Translation projects: '
begin
  cnt = checker.alert_client_about_instant_messages
  tlog += "OK. #{cnt} alerts sent\n"
rescue => e
  tlog += "ERROR\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end
tlog += "Took #{checker.elapsed_time} seconds\n\n"

tlog += 'Delete old abandoned uploads: '
begin
  deleted_dict = checker.delete_old_abandoned_uploads
  deleted_str = (deleted_dict.collect { |k, v| "#{k}: #{v} items" }).join(', ')
  tlog += "deleted #{deleted_str}\n"
rescue => e
  tlog += "ERROR\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end
tlog += "Took #{checker.elapsed_time} seconds\n\n"

tlog += 'Warn clients about low funding: '
begin
  cnt = checker.alert_client_about_low_funding
  tlog += "OK. #{cnt} warnings sent\n"
rescue => e
  tlog += "ERROR\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end
tlog += "Took #{checker.elapsed_time} seconds\n\n"

tlog += 'Cleaning old temporary downloads: '
begin
  checker.clean_old_temp_downloads
  tlog += "OK.\n"
rescue => e
  tlog += "ERROR\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end
tlog += "Took #{checker.elapsed_time} seconds\n\n"

tlog += 'Closing old website translation offers: '
begin
  cnt = checker.close_old_website_offers
  tlog += "Closed #{cnt} offers. Clients notified.\n"
rescue => e
  tlog += "ERROR\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end
tlog += "Took #{checker.elapsed_time} seconds\n\n"

tlog += 'Updating translator rating: '
begin
  Translator.calculate_ratings
  tlog += "OK.\n"
rescue => e
  tlog += "ERROR\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end
tlog += "Took #{checker.elapsed_time} seconds\n\n"

tlog += 'Updating translator jobs_in_progress: '
begin
  Translator.calculate_jobs_in_progress
  tlog += "OK.\n"
rescue => e
  tlog += "ERROR\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end
tlog += "Took #{checker.elapsed_time} seconds\n\n"

tlog += 'Rebuild available languages: '
begin
  res = checker.rebuild_available_languages
  tlog += res
rescue => e
  tlog += "ERROR\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end
tlog += "Took #{checker.elapsed_time} seconds\n\n"

tlog += 'Sending offering logo to clients: '
begin
  res = checker.send_offering_logos(tlog)
rescue => e
  tlog += "ERROR\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end
tlog += "Sent #{res} logos. Took #{checker.elapsed_time} seconds\n\n"

tlog += 'Cleaning up expired UserTokens: '
begin
  res = checker.clean_user_tokens
rescue => e
  tlog += "ERROR\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end
tlog += "Cleaned #{res} tokens. Took #{checker.elapsed_time} seconds\n\n"

tlog += 'Send daily report to clients about completed cms jobs for the past 24 hours'
begin
  cnt = checker.send_daily_completed_jobs_report
  tlog += "OK. Delivered #{cnt} emails\n"
rescue => e
  tlog += "ERROR\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end
tlog += "Took #{checker.elapsed_time} seconds\n\n"

tlog += "\n------- Completed in #{Time.now.to_i - start_time.to_i} seconds -------\n"

log = File.new("#{Rails.root}/log/periodic_daily.log", 'a')
log.write(tlog)
log.close

if error_happened
  ReminderMailer.generic(EMAILS_TO_RECEIVE_ERRORS, "#{Rails.env} - Problems with run_periodic", tlog).deliver_now
end

# @ToDO Delete Resource Uploaded created more than one day ago with status =0
