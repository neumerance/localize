class PopulateManagedWorkAttributes < ActiveRecord::Migration[5.0]
  def change
    # Batches of 5,000 rows
    offset = 0
    limit = 5000

    loop do
      input_query = <<-SQL
        SELECT managed_works.id, wtos.from_language_id, wtos.to_language_id, websites.client_id from managed_works
          INNER JOIN website_translation_offers AS wtos ON
            wtos.id = managed_works.owner_id
            AND managed_works.owner_type = 'WebsiteTranslationOffer'
          INNER JOIN websites ON
            websites.id = wtos.website_id
        WHERE websites.client_id IS NOT NULL
      SQL

      input_query = "#{input_query} LIMIT #{limit} OFFSET #{offset}"
      offset += limit

      query_results = ManagedWork.find_by_sql(input_query)
      
      break if query_results.empty?

      ids_and_values = query_results.map do |row|
        "(#{row.id}, #{row.from_language_id}, #{row.to_language_id}, #{row.client_id})"
      end.compact.join(', ')

      output_query = <<-SQL
        INSERT INTO managed_works (id, from_language_id, to_language_id, client_id)
        VALUES #{ids_and_values}
        ON DUPLICATE KEY UPDATE
          from_language_id = VALUES(from_language_id),
          to_language_id = VALUES(to_language_id),
          client_id = VALUES(client_id);
      SQL

      Client.connection.execute(output_query, :skip_logging)
    end
  end
end
