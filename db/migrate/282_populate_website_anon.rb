class PopulateWebsiteAnon < ActiveRecord::Migration
	def self.up
		Client.where(anon: 1).each do |client|
			client.websites.each { |w| w.update_attributes(:anon=>1) }
		end
	end

	def self.down
	end
end
