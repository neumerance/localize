require 'rubygems'
require 'fileutils'
require 'gpgme'
require 'aws-sdk'

require File.expand_path('../config/environment', File.dirname(__FILE__))

@app = 'icanlocalize'
@environment = Rails.env

def download
  bucket_name = "#{@app}-files-#{@environment}"
  bucket = Aws::S3::Bucket.new(bucket_name)

  @output_dir = bucket_name
  `mkdir -p #{@output_dir}`

  last_key = ARGV.any? ? ARGV.first : 'CmsDownload_494516'

  bucket.objects(marker: last_key).each do |obj_summary|
    file_path = "#{bucket_name}/#{obj_summary.key}"
    begin
      File.open(file_path, 'w') do |fh|
        obj_summary.object.get(response_target: fh)
      end
    rescue EOFError
      puts "Empty file: #{file_path}"
    end
  end
end

def decrypt
  input_dir = "#{@app}-files-#{@environment}"
  FileUtils.mkdir_p('private') unless File.directory?('private')

  crypto = GPGME::Crypto.new
  Dir["#{input_dir}/**"].each do |file_path|
    File.open('tmpfile', 'wb') do |fh|
      fh.write(crypto.decrypt(File.open(file_path)).read)
    end
    `tar -xvf tmpfile`
  end
end

download
decrypt
