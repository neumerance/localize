class AddImportIndexes < ActiveRecord::Migration[5.0]
  def change
    add_index(:parsed_xliffs, [:cms_request_id])

    add_index(:translation_memories,
              [:language_id, :client_id, :signature],
              name: 'translation_memories_index_1')

    add_index(:xliff_trans_unit_mrks,
              [:deleted_at, :xliff_trans_unit_id, :mrk_type],
              name: 'xliff_trans_unit_mrks_index_1')
  end
end
