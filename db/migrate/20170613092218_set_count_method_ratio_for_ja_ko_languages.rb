class SetCountMethodRatioForJaKoLanguages < ActiveRecord::Migration[5.0]
 
  def change
    ja_ko_variations = %w(ja ko)
    Language.find_each do |language|
      next unless ja_ko_variations.include? language.iso
      language.update_attributes!(count_method: 'characters', ratio: 0.50)
    end
  end
end
