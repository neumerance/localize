class ChangeFieldsToStoreXliffOnParsedXliffsToBinary < ActiveRecord::Migration[5.0]
  def change
    change_column :parsed_xliffs, :raw_original, :binary, limit: 5.megabyte
  end
end
