class CreateAvailableLanguages < ActiveRecord::Migration
	def self.up
		create_table :available_languages do |t|
			t.column :from_language_id, :int
			t.column :to_language_id, :int
			t.column :qualified, :int
			t.column :update_idx, :int
		end
		#AvailableLanguage.regenarate()
	end

	def self.down
		drop_table :available_languages
	end
end
