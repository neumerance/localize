module Logging
  def error(error, options)
    base = { error: error.message, trace: format_trace(error) }
    Rails.logger.error(format_hash(base.merge(options)))
  end

  def format_trace(error)
    top_rails_line = error.backtrace.select { |x| x.include?(Rails.root.to_s) }.first
    [error.backtrace.first, top_rails_line].uniq.join(';')
  end

  def format_callstack(context, callstack)
    rails_stack = callstack.select { |l| l.include?(Rails.root.to_s) }
    selected_stack = ([callstack.first] + rails_stack + [callstack.last]).uniq
    selected_stack.map { |line| "[#{Logging.context_name(context)}] #{line}" }.join("\n")
  end

  def log(context, message)
    formatted_message = message.is_a?(Hash) ? format_hash(message) : "[#{message}]"
    Rails.logger.info("[#{Logging.context_name(context)}]#{formatted_message}")
  end

  def log_error(context, error)
    stack = format_callstack(context, error.backtrace)
    Rails.logger.error(format_hash(error: error.class, message: error.message))
    Rails.logger.error(stack)
  end

  def format_hash(hash)
    hash.merge(time: Logging.time).map { |k, v| "[#{k}=#{v}]" }.join
  end

  def time
    Time.current.strftime('%x-%X')
  end

  def context_name(context)
    context.respond_to?(:new) ? context.name : context.class.name
  end

  module_function :error, :format_trace, :format_hash, :format_callstack, :log, :log_error, :time, :context_name
end
