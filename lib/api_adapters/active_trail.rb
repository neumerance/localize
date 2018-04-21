require 'rest-client'

module ApiAdapters
  class ActiveTrail
    ACTIVE_TRAIL_API_URL = 'http://webapi.mymarketing.co.il/api'.freeze

    # Add user to an ActiveTrail group.
    def add_user_to_group(website, group_id, cta_button_link: '', language_pair_names: '')
      return false if website&.client&.email.nil? || group_id.nil?
      do_request(
        :post,
        "/groups/#{group_id}/members",
        user_add_params(
          website,
          cta_button_link: cta_button_link,
          language_pair_names: language_pair_names
        )
      )
    end

    def remove_user_from_group(group_id, contact_id)
      return false if group_id.nil? || contact_id.nil?
      # A response with status 204 and empty body is expected.
      do_request(
        :delete,
        "/groups/#{group_id}/members/#{contact_id}",
        {}
      )
    end

    def list_groups
      do_request(:get, '/groups?Limit=1000', {})
    end

    private

    def user_add_params(website, cta_button_link:, language_pair_names:)
      {
        email: website.client.email,
        first_name: website.client.fname,
        last_name: website.client.lname,
        # Link for the CtA button in the e-mail. ext16 corresponds to the
        # [CtaButtonUrl] tag within ActiveTrail e-mails
        ext16: cta_button_link,
        # Client's website URL. ext17 corresponds to [WpWebsiteUrl]
        ext17: "https://www.icanlocalize.com/wpml/websites/#{website.id}",
        # Client's website title. ext18 corresponds to [WpWebsiteTitle]
        ext18: website.name,
        # Language pairs that require translator assignment.
        # ext19 corresponds to [LanguagePairs]
        ext19: language_pair_names,
        # Trigger automation events (e.g., send e-mail)
        is_trigger_events: true,
        # Required in case we re-add an e-mail that was previously deleted
        is_deleted: false
      }
    end

    def default_headers
      {
        authorization: Figaro.env.activetrail_api_key,
        content_type: :json,
        accept: :json
      }
    end

    def do_request(verb, path, params)
      url = ACTIVE_TRAIL_API_URL + path
      Logging.log(self, "Making request: #{{ verb: verb, url: url, params: params }}")
      begin
        # HTTP client usage: https://github.com/rest-client/rest-client#usage-raw-url
        response = RestClient::Request.execute(
          method: verb,
          url: url,
          payload: params.to_json,
          headers: default_headers
        )
        Logging.log(self, "Response status: #{response.code} / body: #{response.body}")
        return false unless response.code == 200
        JSON.parse(response.body)
      rescue => e
        Logging.log(self, "Error when marking API request: #{e}")
        false
      end
    end
  end
end
