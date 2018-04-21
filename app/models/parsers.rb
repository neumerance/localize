module Parsers

  def logger(message, exception = nil, notify_devs = false)
    log = Logger.new('log/parser_file.log')
    log.info "\n---"
    log.info message

    if exception
      log.error exception.message
      log.error 'Backtrace: '
      log.error Rails.backtrace_cleaner.clean(exception.backtrace).join("\n  ")
      InternalMailer.exception_report(exception).deliver_now if notify_devs
    end
  end
  module_function :logger

  class Parsers::Error < StandardError; end

  class Parsers::ParseError < Parsers::Error
    attr_accessor :suggestions
    def initialize(msg = '', suggestions = false)
      self.suggestions = suggestions
      super(msg)
    end
  end

  class Parsers::EmojisNotSupported < Parsers::Error; end
end
