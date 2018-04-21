class SetCountMethodRatioInLanguages < ActiveRecord::Migration[5.0]
  
  def up
    chinese_variations = %w(zh-Hans zh-Hant)
    Language.find_each do |language|
      if chinese_variations.include? language.iso
        language.update_attributes!(count_method: 'characters', ratio: 0.55)
      else
        language.update_attributes!(count_method: 'words', ratio: 1.0)
      end
    end
  end

  def down
  end
end
