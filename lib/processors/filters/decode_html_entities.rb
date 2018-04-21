require 'htmlentities'

module Processors
  module Filters
    class DecodeHtmlEntities

      def decode(content)
        last_length = content.length
        loop do
          content = HTMLEntities.new.decode(content)
          new_length = content.length
          break if last_length.eql?(new_length)
          last_length = new_length
        end
        content
      end

    end
  end
end
