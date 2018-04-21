class PopulateSupportDepartments < ActiveRecord::Migration
	def self.up
		SupportDepartment.create(:name=>'Projects', :description=>'Creating and managing projects on this website.')
		SupportDepartment.create(:name=>'Translation Assistant', :description=>'Help using Translation Assistant software on your PC.')
		SupportDepartment.create(:name=>'Finance', :description=>'Help making payments or getting paid.')
		SupportDepartment.create(:name=>'General', :description=>'Contact our administrative staff for general inquiries.')
	end

	def self.down
	end
end
