class AddProjectSetupHelpDepartment < ActiveRecord::Migration
	def self.up
		SupportDepartment.create(:name=>SETUP_PROJECT_REQUEST, :description=>SETUP_PROJECT_REQUEST_DESCRIPTION)
	end

	def self.down
		setup_project_request_department = SupportDepartment.where(['name = ?',SETUP_PROJECT_REQUEST]).first
		if setup_project_request_department
			setup_project_request_department.destroy()
		end
	end
end
