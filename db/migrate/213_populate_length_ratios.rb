class PopulateLengthRatios < ActiveRecord::Migration
	def self.up
		ActiveRecord::Base.record_timestamps = false
		cnt = 0
		StringTranslation.all.each do |st|
			st.save
			#cnt += 1
			#if (cnt % 100) == 0
			#	puts "done %d"%cnt
			#end
		end
		ActiveRecord::Base.record_timestamps = true
	end

	def self.down
	end
end
