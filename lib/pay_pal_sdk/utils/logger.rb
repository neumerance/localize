require 'log4r'
require 'singleton'

# The module has a classes and a class method to intialize a logger and to specify formatting style using log4r library.
module PayPalSdk
  module Utils
    # Class has a class method which returs the logger to be used for logging.
    # All the requests sent and responses received will be logged to a file (filename passed to getLogger method) under logs directroy.
    class Logger
      include Singleton
      cattr_accessor :MyLog

      def self.getLogger(filename)

        @@MyLog = Log4r::Logger.new('paypallog')
        # note: The path prepended to filename is based on Rails path structure.
        Log4r::FileOutputter.new('paypal_log',
                                 filename: "./script/../config/../log/#{filename}",
                                 trunc: false,
                                 formatter: PayPalSdk::Utils::MyFormatter)
        @@MyLog.add('paypal_log')
        @@MyLog
      end
    end
  end
end
