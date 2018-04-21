class AddCmsSupportDepartment < ActiveRecord::Migration
	def self.up
		SupportDepartment.create(:name=>CMS_SUPPORT_DEPARTMENT, :description=>CMS_SUPPORT_DEPARTMENT_DESCRIPTION)
	end

	def self.down
		cms_support_department = SupportDepartment.where(name: CMS_SUPPORT_DEPARTMENT).first
		if cms_support_department
			cms_support_department.destroy
		end
	end
end
