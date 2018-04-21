class CreateApiKeysForExistingClients < ActiveRecord::Migration[5.0]
  # This will generate and insert API keys in all 88k clients in a single
  # query, in under 10 seconds (would take ~25 minutes with individual queries).
  def change
    ids = Client.pluck(:id)
    ids_and_api_keys = ids.map { |id| "(#{id}, '#{SecureRandom.uuid}')" }

    # Interpolating ids_and_api_keys would be a SQL injection risk if we did not
    # have complete control over its value

    ids_and_api_keys.each_slice(100).each do |ids|
      query = "INSERT into users (id, api_key)
              VALUES #{ids.join(', ')}
              ON DUPLICATE KEY UPDATE api_key = VALUES(api_key);"

      Client.connection.execute(query, :skip_logging)
    end
  end
end
