class StripStrings < ActiveRecord::Migration
	def self.up
		fixed = 0
		StringTranslation.where('txt is NOT NULL').each do |st|
			if st.txt.strip != st.txt
				st.update_attributes!(:txt=>st.txt.strip)
				fixed += 1
			end
		end
		puts "Fixed #{fixed} strings out of #{StringTranslation.count}"
	end

	def self.down
	end
end
