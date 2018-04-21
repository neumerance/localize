# The module has a class which holds merchant and PayPal endpoint information.
# It has a method which can me mixed in to convert a hash to a string in CGI format.
module PayPalSdk
  module Profiles
    # Method to convert a hash to a string of name and values delimited by '&' as name1=value1&name2=value2...&namen=valuen.
    def hash2cgiString(h)
      h.map { |a| a.join('=') }.join('&')
    end
  end
end
