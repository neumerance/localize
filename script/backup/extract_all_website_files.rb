require 'rubygems'
require 'awesome_print'
require 'colorize'

if ARGV[0].nil?
  puts 'Usage: ./script/runner ./script/backup/extract_all_website_files.rb <website_id> [<location>]'
  exit
end

website_id = ARGV.shift
OUTPUT_DIR = ARGV.shift || '/tmp/icl_website_backup'

website = Website.find website_id

def create_backup_of_zipped_file(zipped_file)
  target_dir_name = OUTPUT_DIR + zipped_file.full_filename.sub(Rails.root, '').chomp(zipped_file.filename)
  FileUtils.mkdir_p(target_dir_name)
  File.cp(zipped_file.full_filename, target_dir_name)
end

website.cms_requests.each do |cms_request|
  puts " * Copying files for cms_request ##{cms_request.id}: #{cms_request.title}..."
  cms_request.cms_uploads.each do |cms_upload|
    create_backup_of_zipped_file cms_upload
  end

  cms_request.cms_target_languages.each do |cms_tl|
    cms_tl.cms_downloads.each do |cms_download|
      create_backup_of_zipped_file cms_download
    end
  end
end

puts 'Done: ' + OUTPUT_DIR
