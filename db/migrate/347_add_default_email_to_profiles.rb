class AddDefaultEmailToProfiles < ActiveRecord::Migration
  def self.up
    TranslationAnalyticsProfile.all.each{|tap| tap.add_default_email}
  end
end
