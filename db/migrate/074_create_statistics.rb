class CreateStatistics < ActiveRecord::Migration
	def self.up
		create_table( :statistics, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
			t.column :version_id, :int
			t.column :stat_code, :int
			t.column :language_id, :int
			t.column :status, :int
			t.column :count, :int
		end

		# create the statistics for uploaded versions
	  ::Version.all.each { |version|
		begin
		  version.update_statistics(false)
		rescue
		  puts "didn't properly create statistics for version #{version.id}"
		end
	  }

		remove_column :revisions, :stats

	end

	def self.down
		drop_table :statistics
		add_column :revisions, :stats, :text
	end
end
