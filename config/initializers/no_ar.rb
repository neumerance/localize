ActiveRecord::Base.logger = Logger.new('/dev/null') unless %w(development test).include?(Rails.env)
