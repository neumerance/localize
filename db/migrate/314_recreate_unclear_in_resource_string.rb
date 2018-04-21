class RecreateUnclearInResourceString < ActiveRecord::Migration
	def self.up
		#ResourceString.where('created_at >= ?',Time.now()-3.months).each do |st|
        #  st.unclear = nil
        #  st.unclear?
        #end
	end
end
