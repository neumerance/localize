class UpdateIsoForChineseLanguages < ActiveRecord::Migration[5.0]
  def up
    {
      "Chinese (Simplified)" => 'zh-Hans',
      "Chinese (Traditional)" => 'zh-Hant'
    }.each do |name, iso|
      update_language name, iso
    end
  end

  def down
    {
      "Chinese (Simplified)" => 'zh-HK',
      "Chinese (Traditional)" => 'zh-CN'
    }.each do |name, iso|
      update_language name, iso
    end
  end

  def update_language(name, iso)
    language = Language.where(name: name).first
    language.update_attribute(:iso, iso) if language
  end
end
