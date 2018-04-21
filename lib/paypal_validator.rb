require 'net/http'
require 'net/https'

class PaypalValidator

  attr_reader :arguments, :postData, :responseString, :responseArray

  def initialize(logger)
    @logger = logger
    @arguments = {}
  end

  def pdt_post_to_paypal(postData, log)
    uri = URI.parse(Figaro.env.PAYPAL_URLS)
    log.info("URL: #{uri}")

    http = Net::HTTP.new(uri.host, 443)
    http.use_ssl = true

    resp = http.post(uri.path, postData, {})
    log.info("RESP: #{resp}, body: #{resp.body}")
    # Net::HTTP.start(uri.host, uri.port) do |request|n
    #	responseString = request.post(uri.path, postData).body
    # end
    resp.body
  end

  def encode_params(params)
    encoded_params = []
    params.each { |k, v| encoded_params << "#{k}=#{URI.escape(v.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}" }
    encoded_params.join('&')
  end

  def validate_pdt(tx)
    begin
    @log = Logger.new("log/pdt.log")
    @postData = encode_params('at' => Figaro.env.PAYPAL_SIG, 'tx' => tx, 'cmd' => '_notify-synch')
    @log.info "POST DATA: #{@postData}"
    @responseString = pdt_post_to_paypal(@postData, @log)
    @log.info("RESPONSE: #{@responseString}")
    @responseArray = @responseString.split
    if (@responseArray.length >= 1) && (@responseArray[0] == 'SUCCESS')
      @arguments = {} # reset the decoded arguments dictionary
      for response in @responseArray
        w = response.split('=')
        @arguments[w[0]] = URI.decode(w[1]) if w.length == 2
      end
      return true
    else
      return false
    end
    rescue Exception => e
      @log.error("EXCEPTION in validate_pdt #{e.to_s}")
      #will not crash, will wait for IPN
      return false
    end
  end

  def validate_ipn(raw_post)
    return false if raw_post.blank?

    retries ||= 3
    begin

      uri = URI.parse(Figaro.env.PAYPAL_URLS + '?cmd=_notify-validate')
      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = 60
      http.read_timeout = 60
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      http.use_ssl = true
      response = http.post(uri.request_uri, raw_post,
                           'Content-Length' => "#{raw_post.size}",
                           'User-Agent' => 'ICL verifier agent')
      status = response.body
      @logger.info "status = '#{status}'"

      raise "Not able to validate" unless status == 'VERIFIED'

      true
    rescue => e
      retries -= 1
      @logger.error "error #{e.message}"

      if retries.zero?
        begin
          raise "Not able to validate IPN after multiple retries.\n Error: #{e.message}\n status = #{status}"
        rescue => e
          InternalMailer.exception_report(e).deliver_now
          @logger.error e.message
          return false
        end
      end

      retry
    end
  end
end
