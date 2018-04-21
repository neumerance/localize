class ChangeParsedXliffsFieldsToBinary < ActiveRecord::Migration[5.0]
  def change
    change_column :parsed_xliffs, :raw_parsed, :binary, limit: 5.megabyte
  end
end
