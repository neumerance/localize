module Processors
  class LateXliffParser
    HOURLY_LIMIT = 100

    def parse
      non_delayed_xliffs.each { |x| ParsedXliff.create_parsed_xliff_by_id(x.id) }
    end

    private

    def non_delayed_xliffs
      handlers = current_delayed_handlers
      non_processed_xliffs.reject do |x|
        handler = "--- !ruby/object:Delayed::PerformableMethod\nobject: !ruby/class 'ParsedXliff'\n" \
                  "method_name: :create_parsed_xliff_by_id_without_delay\nargs:\n- #{x.id}\n"
        handlers.include?(handler)
      end
    end

    def current_delayed_handlers
      @current_delayed_handlers ||= Delayed::Backend::ActiveRecord::Job.where(queue: 'process_xliff').map(&:handler)
    end

    def non_processed_xliffs
      Xliff.where(processed: false, translated: false).
        order(id: :desc).
        limit(HOURLY_LIMIT).
        to_a.
        select(&:needs_processing?)
    end
  end
end
