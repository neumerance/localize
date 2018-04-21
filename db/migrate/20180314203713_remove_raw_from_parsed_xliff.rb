class RemoveRawFromParsedXliff < ActiveRecord::Migration[5.0]
  def change
    remove_column :parsed_xliffs, :raw_parsed, :string
    remove_column :parsed_xliffs, :raw_original, :string
  end
end
