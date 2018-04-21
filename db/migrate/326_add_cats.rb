class AddCats < ActiveRecord::Migration
	def self.up
		Cat.create(:name => "GlobalSight")
		Cat.create(:name => "gtranslator")
		Cat.create(:name => "Idioms")
		Cat.create(:name => "Lokalize")
		Cat.create(:name => "Memo Q")
		Cat.create(:name => "OmegaT")
		Cat.create(:name => "Open Language Tools")
		Cat.create(:name => "Poedit")
		Cat.create(:name => "Pootle")
		Cat.create(:name => "SDL Trados")
		Cat.create(:name => "Virtaal")
		Cat.create(:name => "Web Translate")
		Cat.create(:name => "Wordbee")
		Cat.create(:name => "Wordfast")
	end
end
