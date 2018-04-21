class PopulateTaToolParent < ActiveRecord::Migration[5.0]
  def up
    CmsRequest.update_all(ta_tool_parent_completed: true)
  end
end
