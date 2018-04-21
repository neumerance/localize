class UpdatePlistXPath < ActiveRecord::Migration
  def self.up
    plist_format = ResourceFormat.where(name: 'plist').first
    if plist_format
      plist_format.update_attribute :label_delimiter, 'plist/array/dict|plist/dict'
    end
  end

  def self.down
    plist_format = ResourceFormat.where(name: 'plist').first
    if plist_format.nil?
      plist_format.update_attribute :label_delimiter, 'plist/dict'
    end
  end
end
