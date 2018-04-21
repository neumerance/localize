module Processors
  module Filters
    class RemoveWhiteSpaces

      def filter(content)
        content.gsub(/[[:space:]]+/, '').strip
      end
    end
  end
end
