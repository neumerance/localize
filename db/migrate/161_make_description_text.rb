class MakeDescriptionText < ActiveRecord::Migration
	def self.up
		# 1. remember all the descriptions for existing projects
		descriptions = {}
		TextResource.all.each { |t| descriptions[t.id] = t.description }
	
		# 2. change the column type
		remove_column :text_resources, :description
		add_column :text_resources, :description, :text
		
		# 3. save back all the descriptions
		TextResource.all.each { |t| t.update_attributes(:description=>descriptions[t.id]) }
	end

	def self.down
	end
	
end
