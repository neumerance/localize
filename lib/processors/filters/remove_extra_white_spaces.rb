module Processors
  module Filters
    class RemoveExtraWhiteSpaces

      def filter(content)
        content.gsub(/[[:space:]]/, ' ')
      end
    end
  end
end
