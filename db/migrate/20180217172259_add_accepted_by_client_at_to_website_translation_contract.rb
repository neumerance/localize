class AddAcceptedByClientAtToWebsiteTranslationContract < ActiveRecord::Migration[5.0]
  def change
    add_column :website_translation_contracts, :accepted_by_client_at, :datetime

    # Performs one query for each 5,000 records
    WebsiteTranslationContract.in_batches(of: 5000) do |wtc_batch|
      ids_and_updated_ats_array = wtc_batch.pluck(:id, :updated_at)
      ids_and_updated_ats_for_sql = ids_and_updated_ats_array.map do |row|
        next if row[1].nil?
        "(#{row[0]}, '#{row[1].to_s(:db)}')"
      end.compact.join(', ')

      query = <<-SQL
        INSERT INTO website_translation_contracts (id, accepted_by_client_at)
        VALUES #{ids_and_updated_ats_for_sql}
        ON DUPLICATE KEY UPDATE 
          -- Only set accepted_by_client_at if the WTC status is 2
          accepted_by_client_at = IF(status = 2, VALUES(accepted_by_client_at), NULL);
      SQL

      WebsiteTranslationContract.connection.execute(query, :skip_logging)
    end
  end
end
