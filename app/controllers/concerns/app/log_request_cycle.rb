require 'openssl'

module App
  module LogRequestCycle
    KERNEL_PAGE_SIZE = 4096
    STATM_PATH       = "/proc/#{Process.pid}/statm".freeze
    STATM_FOUND      = File.exist?(STATM_PATH)

    # Im not sure if this returns the memory of whole mongrel instance or only current request
    def memory_usage
      if STATM_FOUND
        (File.read(STATM_PATH).split(' ')[1].to_i * KERNEL_PAGE_SIZE) / 1024 / 1024
      else
        log ' ** Using newrelic to get memory information (Not linux?) **'
        NewRelic::Agent::Samplers::MemorySampler.new.sampler.get_sample.to_i
      end
    rescue
      log ' ** Not able to get memory information'
      0
    end

    def request_log(str)
      log str
    end

    def log_request_start
      @log_request_cycle_start_time = Time.now
      log "--------- #{@log_request_cycle_start_time.strftime('%e-%b-%Y %l:%M:%S %p')} --------"
      @initial_memory = memory_usage
    end

    def log_info
      log "url: #{request.url}"
      log "ip: #{request.remote_ip}"
      log "Pid: #{Process.pid}"
      log "Initial Memory: #{@initial_memory} Mb"
      # log "Port: #{(`ps -p #{$$} -o command= | tail -c 9`).strip}"
      log "UserAgent: #{request.user_agent}"
      log "Session: #{session[:session_num]}"
      log('Parameters: ' + params.inspect)
    end

    def hangup_server
      2.times do
        log 'Hangup server!'
      end

    end

    def log_request_end
      total_time = Time.now - @log_request_cycle_start_time
      final_memory = memory_usage
      log "Total Time: #{total_time}s"
      log "Total Memory: #{final_memory} Mb"
      log "Application Memory: #{final_memory - @initial_memory}Mb"
      log "END\r\n"
    end

    private

    def log(str)
      @random ||= OpenSSL::Random.random_bytes(6).unpack('H*').join
      File.open("#{Rails.root}/log/requests_live_cycle.log", 'a') do |a|
        time = Time.now
        ms = time.to_f.to_s.split('.').last[0..2]
        begin
          a.write "\r\n * #{@random} [#{time.strftime('%H:%M:%S')}] #{str}"
        rescue => e
          a.write "\r\n * #{@random} [#{time.strftime('%H:%M:%S')}] #{e.inspect}"
        end
      end
    end
  end
end
