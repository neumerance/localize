class PopulateOldFormatFlags < ActiveRecord::Migration
	def self.up
		WebMessage.all.each { |w| w.update_attributes(:old_format=>1) }
	end

	def self.down
	end
end
