module Processors
  module WordCounter

    def self.count(sentence, count_method, ratio)
      if count_method.to_s.eql?(CountMethod::Words.new.name)
        word_count = Processors::Counters::Words.new.count(sentence)
      else
        characters_count = Processors::Counters::Ideograms.new.count(sentence)
        word_count = (characters_count * ratio).round
      end
      word_count
    end
  end
end
