class UpdateMalayLanguageIsoCode < ActiveRecord::Migration
  def self.up
    l = Language.find_by_name "Malay"
    l.update_attribute :iso, 'ms' if l
  end

  def self.down
    l = Language.find_by_name "Malay"
    l.update_attribute :iso, 'ms_MY' if l
  end
end
