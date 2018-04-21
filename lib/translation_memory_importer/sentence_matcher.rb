module TranslationMemoryImporter
  class SentenceMatcher

    def initialize(sentence)
      @sentence = sentence
    end

    def find_match
      Tu.where(original: @sentence).first
    end
  end
end
