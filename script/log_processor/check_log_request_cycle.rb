require 'rubygems'
require 'awesome_print'
require 'colorize'
# This file check all records on log_request_cycle.log and output the ones
# that dont have an END
# Usage:
#    # ruby script/log_processor/check_log_request_cycle.rb

regex = /\* ([\d\w]+) \[(.*)\] (.*)/
requests = {}

class Request
  attr_accessor :logs, :finished, :seed
  def initialize(seed)
    @logs = []
    @finished = false
    @seed = seed
  end

  def log(data, time = '')
    @logs << "[#{time.yellow}] #{data}"
    @finished = true if data == 'END'
  end

  def status
    @finished ? 'OK'.green : 'FAILED'.red
  end

  class << self
    def get_by_seed(seed)
      @requests ||= {}
      @array ||= []
      unless @requests[seed]
        @requests[seed] = Request.new seed
        @array << @requests[seed]
      end
      @requests[seed]
    end

    def get_requests
      @array
    end
  end
end

File.readlines('log/requests_live_cycle.log').each do |line|
  line.strip!
  result = line.match regex

  if !result.nil? && result.length == 4
    seed = result[1]; time = result[2]; data = result[3]
    r = Request.get_by_seed(seed)
    r.log(data, time)
  else
    ap "line dont match: #{line}" unless line.empty?
  end
end

totals = { ok: 0, failed: 0 }
Request.get_requests.each do |r|
  # puts "#{r.seed}: #{r.status}"
  if r.finished
    totals[:ok] += 1
  else
    totals[:failed] += 1
    puts "#{r.seed}: #{r.status}"
    r.logs.each do |l|
      puts "    #{l}"
    end
  end
end

puts '----- Results -----'
puts 'ok: '.green + " #{totals[:ok]}"
puts 'failed: '.red + " #{totals[:failed]}"
