class AddSupportTicketObject < ActiveRecord::Migration
	def self.up
		add_column :support_tickets, :object_type, :string
		add_column :support_tickets, :object_id, :integer
		SupportDepartment.create(:name=>SUPPORTER_QUESTION, :description=>SUPPORTER_QUESTION_DESCRIPTION)
	end

	def self.down
		remove_column :support_tickets, :object_type
		remove_column :support_tickets, :object_id
		supporter_question_department = SupportDepartment.where(['name = ?',SUPPORTER_QUESTION]).first
		if supporter_question_department
			supporter_question_department.destroy()
		end
	end
end
