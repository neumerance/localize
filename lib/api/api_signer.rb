require 'openssl'
require 'Base64'
require 'time'
require 'uri'
require 'pathname'

class ApiSigner

  TIME_TO_LIVE_FOR_REQUEST = 5.minutes

  class << self

    def sign(method, url, timestamp)
      uri = URI(url)
      data_to_sign = canonical_url(method, uri, timestamp)
      signature(data_to_sign, Figaro.env.TP_ACCESSKEY)
    end

    def validate_signature(method, url, timestamp, signature)
      return false unless Time.now.to_i - timestamp < TIME_TO_LIVE_FOR_REQUEST
      signature == sign(method, url, timestamp)
    end

    private

    def canonical_url(method, uri, timestamp)
      [
        method,
        timestamp,
        Pathname.new(uri.path).cleanpath.to_s,
        uri.query
      ].join('_')
    end

    def signature(data, key)
      Base64.encode64(OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), key, data)).strip
    end
  end

end
