class FixOwners < ActiveRecord::Migration
	def self.up
		TextResource.where('(owner_type = ?) OR (owner_id = ?) OR (owner_id IS NULL)','','').each { |t| t.update_attributes!(:owner_id=>nil, :owner_type=>nil) }
	end

	def self.down
	end
end
