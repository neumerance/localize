module Processors
  module Counters
    class Ideograms

      def count(content)
        content = Processors::Filters::RemovePunctuationMarks.new.filter(content)
        content = Processors::Filters::DecodeHtmlEntities.new.decode(content)
        content = Processors::Filters::RemoveHtml.new.filter(content)
        content = Processors::Filters::RemoveWhiteSpaces.new.filter(content)
        content.size
      end
    end
  end
end
