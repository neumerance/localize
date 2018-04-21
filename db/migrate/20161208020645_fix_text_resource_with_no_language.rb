class FixTextResourceWithNoLanguage < ActiveRecord::Migration[5.0]
  def change
    TextResource.fix_text_resource_with_no_language
  end
end
