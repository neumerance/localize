class AddAw3S3Path < ActiveRecord::Migration
	def self.up
		add_column :zipped_files, :aws_s3_path, :string		
	end

	def self.down
		remove_column :zipped_files, :aws_s3_path
	end
end
