class AddPortuguesePortuguese < ActiveRecord::Migration
	def self.up
			name = 'Portugal Portuguese'
			lang = Language.where(name: name).first
			if not lang
				Language.create(:name => name, :major => 0)
			else
				lang.major = 0
				lang.save!
			end
	end

	def self.down
	end
end
