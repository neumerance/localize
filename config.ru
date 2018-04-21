# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment', __FILE__)
run Icanlocalize::Application
use Rack::RubyProf, path: 'public/profile' if PROFILER_ENABLED

DelayedJobWeb.use Rack::Auth::Basic do |username, password|
  ActiveSupport::SecurityUtils.variable_size_secure_compare(Figaro.env.DJ_WEB_USER, username) &&
    ActiveSupport::SecurityUtils.variable_size_secure_compare(Figaro.env.DJ_WEB_PASS, password)
end
