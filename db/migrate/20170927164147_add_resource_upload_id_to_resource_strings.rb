class AddResourceUploadIdToResourceStrings < ActiveRecord::Migration[5.0]
  def change
    add_reference :resource_strings, :resource_upload
  end
end
