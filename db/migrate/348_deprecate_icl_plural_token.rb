class DeprecateIclPluralToken < ActiveRecord::Migration
  def self.up
    ResourceString.includes(:string_translations).where("txt like '%ICL_PLURAL%'").each do |resource_string|

      parent_ids = []
      [0,1].each do |i|
        texts = resource_string.txt.split(/#{Regexp.escape(PLURAL_SEPARATOR)}/)
        new_string = resource_string.clone
        new_string.txt = texts[i].strip if texts.size > i
        new_string.token = Digest::MD5.hexdigest(texts[i].strip) if texts.size > i
        begin
          new_string.save!
          parent_ids << new_string.id
        rescue => e
          puts e.inspect
        end
      end

      resource_string.string_translations.each do |string_translation|
        [0,1].each do |i|
          texts2 = string_translation.txt.split(/#{Regexp.escape(PLURAL_SEPARATOR)}/) if string_translation and string_translation.txt
          new_string2 = string_translation.clone
          new_string2.txt = texts2[i].strip if texts2 and texts2.size > i
          new_string2.resource_string_id = parent_ids[i]
          begin
            new_string2.save!
          rescue => e
            puts e.inspect
          end
        end
      end
    end
  end
end
