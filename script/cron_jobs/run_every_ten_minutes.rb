# BE CAREFUL about what you include here, it may take a lot of server resources

start_time = Time.now
error_happened = false

def time_as_string
  Time.now.strftime('%F %T')
end

tlog = "\n\n------- Every 10 minutes #{Rails.env} starting at: #{time_as_string} --------\n\n"

tlog += "Trigger ActiveTrail flow for website projects: no jobs sent.\n"
begin
  cnt = ActiveTrailAction.notify_websites_no_jobs_sent
  tlog += "OK. Notified clients about #{cnt} websites with no jobs sent.\n\n"
rescue StandardError => e
  tlog += "ERROR\n"
  tlog += "Message: #{e.message}\n\n"
  tlog += "Inspect: #{e.inspect}\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end

tlog += "Trigger ActiveTrail flow for website projects: translator invitation required.\n"
begin
  cnt = ActiveTrailAction.notify_websites_translator_invitation_required
  tlog += "OK. Notified clients about #{cnt} websites containing language pairs " \
          "requiring manual translator invitation.\n\n"
rescue StandardError => e
  tlog += "ERROR\n"
  tlog += "Message: #{e.message}\n\n"
  tlog += "Inspect: #{e.inspect}\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end

tlog += "Trigger ActiveTrail flow for website projects: payment required.\n"
begin
  cnt = ActiveTrailAction.notify_websites_payment_required
  tlog += "OK. Notified clients about #{cnt} websites with unpaid translation jobs.\n\n"
rescue StandardError => e
  tlog += "ERROR\n"
  tlog += "Message: #{e.message}\n\n"
  tlog += "Inspect: #{e.inspect}\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end

tlog += "\n------- Completed in #{Time.now.to_i - start_time.to_i} seconds -------\n"

log = File.new("#{Rails.root}/log/periodic_every_ten_minutes.log", 'a')
log.write(tlog)
log.close

if error_happened
  ReminderMailer.generic(EMAILS_TO_RECEIVE_ERRORS, "#{Rails.env} - Problems with run_every_ten_minutes", tlog).deliver_now
end
