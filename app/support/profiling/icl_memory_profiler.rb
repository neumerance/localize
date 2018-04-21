module Profiling
  class IclMemoryProfiler
    class << self
      def setup
        return if disabled?
        require 'memory_profiler'
      end

      def start
        return if disabled?
        MemoryProfiler.start
      rescue StandardError => ex
        Logging.log_error(self, ex)
      end

      def dump(path = dump_path)
        return if disabled?

        Logging.log(self, stats: :started)

        report = MemoryProfiler.stop
        FileUtils.mkpath(path)
        Logging.log(self, stats: :collected)

        dump_result_to_path(report, path)

        start
      rescue StandardError => ex
        Logging.log_error(self, ex)
      end

      def dump_if_need
        return if disabled?
        return unless Rails.env.production? || Rails.env.sandbox?
        path = dump_path
        return if File.exist?(path)
        dump(path)
      end

      private

      def disabled?
        true
      end

      def dump_result_to_path(report, path)
        Logging.log(self, dump: :started)
        File.open(path + '/report.txt', 'w') { |f| PP.pp(report, f) }
        Logging.log(self, dump: :finished)
      end

      def current_dump_path
        now = Time.current
        date = now.strftime('%x').tr('/', '_')
        "date_#{date}_hour_#{now.hour}_min_#{now.min}__pid_#{Process.pid}"
      end

      def dump_path
        Rails.root.join('log', 'memprof', current_dump_path).to_s
      end
    end
  end
end
