class StripBios < ActiveRecord::Migration
	def self.up
		Translator.where('(bio is NOT NULL) AND (bio != "")').each do |translator|
			translator.update_attributes(:bio=>translator.bio.strip)
		end
	end

	def self.down
	end
end
