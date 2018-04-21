class AddUnclearToResourceString < ActiveRecord::Migration
	def self.up
		add_column :resource_strings, :unclear, :boolean
		#ResourceString.all.each{|st| st.unclear?}
	end

	def self.down
		remove_column :resource_strings, :unclear
	end
end
