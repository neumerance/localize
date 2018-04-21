#!/usr/bin/env ruby
require 'rubygems'
require 'fileutils'
require 'aws-sdk'

require File.expand_path('../config/environment', File.dirname(__FILE__))

BASE_DIR = '/tmp/'.freeze
BUCKET_NAME = Figaro.env.aws_s3_bucket

GPG_PATH = IO.popen('which gpg').read.chomp
(puts 'gpg not in your path'; exit 1) if GPG_PATH.empty?
GIT_PATH = IO.popen('which git').read.chomp
(puts 'git not in your path'; exit 1) if GIT_PATH.empty?
UNZIP_PATH = IO.popen('which unzip').read.chomp
(puts 'unzip not in your path'; exit 1) if UNZIP_PATH.empty?

def fetch_file(file_name)
  puts "Fetching #{file_name} from S3..."

  bucket = Aws::S3::Bucket.new(BUCKET_NAME)
  s3object = bucket.object(file_name)

  unless s3object.exists?
    puts "Could not find file #{file_name} on bucket #{BUCKET_NAME}"
    exit 1
  end

  puts 'saving file: ' + BASE_DIR + file_name
  s3object.get(response_target: File.join(BASE_DIR, file_name))
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

id = ARGV.first

fetch_file('Version_' + id)
decrypt_file('Version_' + id)
