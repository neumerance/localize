class FindOriginalMasterStrings < ActiveRecord::Migration
	def self.up
		strings = ResourceString.where('master_string_id IS NOT NULL')
		for string in strings
			master_string = string.master_string
			while master_string.master_string
				master_string = master_string.master_string
			end
			if master_string != string.master_string
				string.update_attributes(:master_string_id=>master_string.id)
			end
		end
	end

	def self.down
	end
end
