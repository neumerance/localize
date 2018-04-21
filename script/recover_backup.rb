#!/usr/bin/env ruby
require 'rubygems'
require 'fileutils'
require 'aws-sdk'

require File.expand_path('../config/environment', File.dirname(__FILE__))

BASE_DIR = '/tmp/'.freeze
BUCKET_NAME = 'onthegosystems_trac_and_svn'.freeze
ICANLOCALIZE_GIT_URL = 'git@git.icanlocalize.com:fotanus/icanlocalize.git'.freeze

GPG_PATH = IO.popen('which gpg').read.chomp
(puts 'gpg not in your path'; exit 1) if GPG_PATH.empty?
GIT_PATH = IO.popen('which git').read.chomp
(puts 'git not in your path'; exit 1) if GIT_PATH.empty?
UNZIP_PATH = IO.popen('which unzip').read.chomp
(puts 'unzip not in your path'; exit 1) if UNZIP_PATH.empty?

def usage
  puts "#{$0} YYYYMMDD [Options]"
  puts 'Options'
  puts "\t--skip-git\tDon't download the code and setup the database"
end

def parse_args
  if ARGV.empty? || !(ARGV.first =~ /\d{8}/)
    usage
    exit 1
  end

  year = ARGV.first[0..3].to_i
  month = ARGV.first[4..5].to_i
  day = ARGV.first[6..7].to_i

  confs = {}
  months = %w(nil Jan Feb Mar Apr May Jun Jul Ago Sep Oct Nov Dez)
  confs[:file_name] = "icanlocalize_production_#{months[month]}_#{day}_#{year}.sql.zip.pgp"

  confs[:skip_git] = ARGV.include?('--skip-git')

  confs
end

def fetch_file(file_name)
  if File.exist?(BASE_DIR + file_name)
    puts "File #{file_name} already exists in #{BASE_DIR}"
  else
    puts "Fetching #{file_name} from S3..."

    bucket = Aws::S3::Bucket.new(BUCKET_NAME)
    s3object = bucket.object(file_name)

    unless s3object.exists?
      puts "Could not find file #{file_name} on bucket #{BUCKET_NAME}"
      exit 1
    end

    s3object.get(response_target: File.join(BASE_DIR, file_name))
  end
end

def decrypt_file(file_name)
  if File.exist?(BASE_DIR + file_name[0..-5])
    puts 'Already decrypted'
  else
    puts 'Decrypting file...'
    puts "#{GPG_PATH} #{BASE_DIR + file_name}"
    system "#{GPG_PATH} #{BASE_DIR + file_name}"
  end
end

def unzip_file(file_name)
  decrypted_file = file_name[0..-5]
  unziped_file = file_name[0..-9]
  if File.exist?(unziped_file)
    puts 'File already unziped'
  else
    puts 'Unziping file...'
    system "#{UNZIP_PATH} #{BASE_DIR + decrypted_file}"
  end
end

def setup_new_icanlocalize(file_name)
  icanlocalize_new_folder = "icanlocalize_#{ARGV}"
  if File.exist?(icanlocalize_new_folder)
    puts 'ICanLocalize code already fetched'
  else
    puts 'Fetching ICanLocalize code...'
    system "#{GIT_PATH} co #{ICANLOCALIZE_GIT_URL} #{icanlocalize_new_folder}"
    fix_database(file_name, icanlocalize_new_folder)
  end

end

def fix_database(file_name, icanlocalize_new_folder)
  puts 'Tweaking configuration files...'
  database_file = icanlocalize_new_folder + '/config/database.yml'
  modified_file = ''
  File.open(database_file, 'r').read.split("\n").each do |line|
    if line =~ /^(.*database: icanlocalize(_test|_production|_sandbox|_development)).*$/
      matched_substr = $1
      line = matched_substr + "_#{ARGV.first}" unless line =~ /#{ARGV.first}/
    end
    modified_file += line + "\n"
  end

  File.open(database_file, 'w') { |fh| fh.write modified_file }
  puts 'Setting up database...'
  Dir.chdir icanlocalize_new_folder do
    system 'rake db:create'
  end

  database_file = file_name[0..-9]
  system "mysql -u icanlocalize --password=eehelzer icanlocalize_development_#{ARGV.first} < #{database_file}"

  puts 'Migrating...'
  Dir.chdir icanlocalize_new_folder do
    system 'rake db:migrate'
  end
end

### MAIN ###
confs = parse_args
fetch_file(confs[:file_name])
puts ''
decrypt_file(confs[:file_name])
puts ''
unzip_file(confs[:file_name])
puts ''
setup_new_icanlocalize(confs[:file_name]) unless confs[:skip_git]
