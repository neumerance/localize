class CreateWebsiteReportFormats < ActiveRecord::Migration
	def self.up
		create_table( :website_report_formats, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :website_id, :integer
			t.column :format, :text
			t.column :filter, :text
			t.column :pagination_kind, :integer
			t.timestamps
		end
		add_index :website_report_formats, [:website_id], :name=>'website', :unique=>false
	end

	def self.down
		drop_table :website_report_formats
	end
end
