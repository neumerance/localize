module Processors
  module Filters
    class RemovePunctuationMarks

      def filter(content)
        content.gsub(/[[:punct:]]+/, '').strip
      end
    end
  end
end
