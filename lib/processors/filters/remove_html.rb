require 'sanitize'

module Processors
  module Filters
    class RemoveHtml

      def filter(content)
        Sanitize.fragment(content).strip
      end
    end
  end
end
