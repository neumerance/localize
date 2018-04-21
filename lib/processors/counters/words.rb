require 'word_count_analyzer'

module Processors
  module Counters
    class Words

      def initialize(options = {})
        options = { contraction: 'count_as_one',
                    numbered_list: 'ignore',
                    xhtml: 'remove',
                    forward_slash: 'count_as_one',
                    underscore: 'count' }.merge(options)

        @word_count_analyzer = WordCountAnalyzer::Counter.new(options)
      end

      def count(content)
        content = Processors::Filters::RemoveExtraWhiteSpaces.new.filter(content)
        @word_count_analyzer.count(content)
      end
    end
  end
end
