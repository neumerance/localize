# open log file
start_time = Time.now

hour = (start_time.to_i / (60 * 60)).to_i

error_happened = false

def time_as_string
  Time.now.strftime(TIME_FORMAT_STRING)
end

tlog = "\n\n------- hourly #{Rails.env} starting at: #{time_as_string} --------\n\n"

# email processing

e = EmailChecker.new
tlog += 'Processing incoming emails: '
begin
  cnt = e.process_new_emails
  tlog += "OK. Processed #{cnt} emails\n"
rescue Exception => e
  tlog += "ERROR\n"
  tlog += "Message: #{e.message}\n\n"
  tlog += "Inspect: #{e.inspect}\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end
tlog += "Took #{Time.now - start_time} seconds\n\n"

#  set up the periodic checker
checker = PeriodicChecker.new(start_time)

tlog += 'Send follow up e-mails for new clients: '
begin
  cnt = checker.send_follow_up_emails
  tlog += "OK. Sent #{cnt} emails\n"
rescue Exception => e
  tlog += "ERROR\n"
  tlog += "Message: #{e.message}\n\n"
  tlog += "Inspect: #{e.inspect}\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end
tlog += "Took #{checker.elapsed_time} seconds\n\n"

tlog += 'clean_old_sessions: '
begin
  checker.clean_old_sessions
  tlog += "OK\n"
rescue Exception => e
  tlog += "ERROR\n"
  tlog += "Message: #{e.message}\n\n"
  tlog += "Inspect: #{e.inspect}\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end
tlog += "Took #{checker.elapsed_time} seconds\n\n"

tlog += 'send per-translator new projects emails: '
begin
  cnt = checker.per_profile_mailer
  tlog += "OK. Sent #{cnt} emails\n"
rescue Exception => e
  tlog += "ERROR\n"
  tlog += "Message: #{e.message}\n\n"
  tlog += "Inspect: #{e.inspect}\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end
tlog += "Took #{checker.elapsed_time} seconds\n\n"

tlog += 'release held instant messages: '
begin
  messages = checker.release_old_instant_messages
  tlog += "OK. Released #{messages.length} held instant messages\n"
  messages.each do |message|
    release_result = message.translation_in_progress? ? 'ERROR' : 'OK'
    tlog += " --- message.#{message.id} #{release_result}\n"
  end
rescue Exception => e
  tlog += "ERROR\n"
  tlog += "Message: #{e.message}\n\n"
  tlog += "Inspect: #{e.inspect}\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end
tlog += "Took #{checker.elapsed_time} seconds\n\n"

if (hour % 4) == 0
  tlog += 'Reminding about old instant messages: '
  begin
    cnt = checker.remind_about_instant_messages
    tlog += "OK. #{cnt} reminders sent\n"
  rescue Exception => e
    tlog += "ERROR\n"
    tlog += "Message: #{e.message}\n\n"
    tlog += "Inspect: #{e.inspect}\n"
    tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
    error_happened = true
  end
end
tlog += "Took #{checker.elapsed_time} seconds\n\n"

tlog += 'Flush out error CMS requests: '
begin
  cnt = checker.flush_cms_requests
  tlog += "OK. #{cnt} CMS requests flushed\n"
rescue Exception => e
  tlog += "ERROR\n"
  tlog += "Message: #{e.message}\n\n"
  tlog += "Inspect: #{e.inspect}\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end
tlog += "Took #{checker.elapsed_time} seconds\n\n"

tlog += 'Reset CMS Request with pending_tas = 0 and no versions on it: '
begin
  cnt = checker.reset_cms_requests_with_no_versions
  tlog += "OK. #{cnt} reminders sent\n"
rescue => e
  tlog += "ERROR\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end
tlog += "Took #{checker.elapsed_time} seconds\n\n"

tlog += 'Clean up old database entries: '
begin
  old = Time.now - 2.months
  UserClick.delete_all ['updated_at < ?', old]
  CommError.delete_all ['updated_at < ?', old]
  ErrorReport.delete_all ['submit_time < ?', old]
  tlog += "OK. #{cnt} removed old database entries\n"
rescue Exception => e
  tlog += "ERROR\n"
  tlog += "Message: #{e.message}\n\n"
  tlog += "Inspect: #{e.inspect}\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end
tlog += "Took #{checker.elapsed_time} seconds\n\n"

begin
  require_relative './processors/late_xliff_parser'
  Processors::LateXliffParser.new.parse
rescue Exception => e
  tlog += "ERROR\n"
  tlog += "Message: #{e.message}\n\n"
  tlog += "Inspect: #{e.inspect}\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end

tlog += 'Send e-mails to supporters notifying them about language pairs that ' \
        'require "automatic" translator assignment: '
begin
  cnt = checker.send_auto_assign_needed_emails
  tlog += "OK. Found #{cnt} language pairs requiring \"automatic\" assignment. #{'Sent 1 email.' if cnt > 0}\n"
rescue Exception => e
  tlog += "ERROR\n"
  tlog += "Message: #{e.message}\n\n"
  tlog += "Inspect: #{e.inspect}\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end

tlog += 'Send e-mail to supporters about auto-assigned jobs which have not started ' \
        'after 24 hours the job was accepted by translators: '
begin
  cnt = checker.send_unstarted_auto_assign_jobs
  tlog += "OK. Found #{cnt} auto-assigned jobs which have not yet started after 24 hrs. #{'Sent 1 email.' if cnt > 0}\n"
rescue Exception => e
  tlog += "ERROR\n"
  tlog += "Message: #{e.message}\n\n"
  tlog += "Inspect: #{e.inspect}\n"
  tlog += "Backtrace: #{e.backtrace.join("\n\t")}\n"
  error_happened = true
end

tlog += "Took #{checker.elapsed_time} seconds\n\n"

tlog += "\n------- Completed in #{Time.now.to_i - start_time.to_i} seconds -------\n"

log = File.new("#{Rails.root}/log/periodic_hourly.log", 'a')
log.write(tlog)
log.close

if error_happened
  ReminderMailer.generic(EMAILS_TO_RECEIVE_ERRORS, "#{Rails.env} - Problems with run_hourly", tlog).deliver_now
end
