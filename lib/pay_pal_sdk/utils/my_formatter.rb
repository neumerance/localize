require 'log4r'

# The module has a classes and a class method to intialize a logger and to specify formatting style using log4r library.
module PayPalSdk
  module Utils
    # Class and method to redefine the log4r formatting.
    class MyFormatter < Log4r::Formatter
      def format(event)
        buff = Time.now.strftime('%a %m/%d/%y %H:%M %Z')
        buff += " - #{Log4r::LNAMES[event.level]}"
        buff += " - #{event.data}\n"
      end
    end
  end
end
