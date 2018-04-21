class AddErrorReportToCommError < ActiveRecord::Migration
	def self.up
		add_column :comm_errors, :error_report, :text
	end

	def self.down
		remove_column :comm_errors, :error_report
	end
end
