class AddTextResourceVersionNum < ActiveRecord::Migration
	def self.up
		add_column :text_resources, :version_num, :int, :default=>0
	end

	def self.down
		remove_column :text_resources, :version_num
	end
end
