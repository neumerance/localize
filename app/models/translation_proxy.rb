require 'singleton'
require 'rest-client'

class TranslationProxy
  include Singleton

  # Class responsible for sending and parsing response of notifications
  class Notification

    def self.cancel(cms_request, secondtry = false)
      notify_tp(cms_request, secondtry, 'translation_cancelled')
    end

    def self.deliver(cms_request, secondtry = false)
      notify_tp(cms_request, secondtry, 'translation_ready')
    end

    def self.notify_tp(cms_request, secondtry, notification)
      website = cms_request.website
      website = website.reverse_api_version if secondtry
      version = tp_config_version(website)
      params = build_params(website, version, job_id: cms_request.id, notification: notification)
      begin
        post "/service/notifications/#{Figaro.env.send("TP_SUID#{version}")}", params
      rescue RestClient::ResourceNotFound => e
        if secondtry
          # See icldev-2416 for details.
          Rails.logger.info "[#{self.class.name}] - TP returned 404 twice " \
                            "when trying to deliver cms_request #{cms_request.id}." \
                            "Giving up. Response was: #{e}"
          return
        end
        notify_tp(cms_request, true, notification)
      end
    end

    class TPError < JSONError
      def initialize(msg)
        @code = TP_ERROR
        @message = msg
      end
    end

    private_class_method

    def self.build_params(_website, version, set_params = {})
      set_params[:api_version] = Figaro.env.send("TP_API_VERSION#{version}")
      set_params[:accesskey] = Figaro.env.send("TP_ACCESSKEY#{version}")
      set_params[:suid] = Figaro.env.send("TP_SUID#{version}")
      set_params
    end

    def self.tp_config_version(website)
      api_version = website.api_version
      return '' if api_version.nil? || api_version == '1.0'
      '_V2'
    end

    def self.default_headers
      {
        content_type: :json,
        accept: :json
      }
    end

    def self.post(path, params)
      do_request(:post, path, params)
    end

    def self.do_request(verb, path, params)
      Rails.logger.info '== Sending message to TP =='
      Rails.logger.info "== #{verb} #{Figaro.env.TP_URL}#{path} #{params.inspect}"
      begin
        url = "#{Figaro.env.TP_URL}#{path}"
        resp_body = RestClient.send(verb, url, params, default_headers)

        Rails.logger.info "== Response: #{resp_body.inspect}"
        JSON.parse(resp_body)
      rescue SocketError => e
        raise TPError, "Can't connect to TP on URL #{url}"
      rescue JSON::ParserError => e
        raise TPError, "TP returned invalid json: #{e}"
      rescue => e
        if e.is_a? RestClient::ResourceNotFound
          raise e
        else
          raise TPError, e
        end
      end
    end
  end
end
