module StringExtensions
  def humanize
    if MY_FIELDS.key?(to_s)
      MY_FIELDS[to_s]
    else
      super
    end
  end

  def get_urls
    scan(/(?:http|www)[^\s]*/i).collect! { |url| url =~ /^http/ ? url : "http://#{url}" }
  end

  def sanitized_split
    txt = self.dup
    txt = txt.gsub('<![CDATA[', '')
    txt = txt.gsub(']]>', '')
    txt = txt.strip_html_tags
    txt = txt.gsub('\n', ' ')
    urls = txt.scan(/(?:http|www)[^\s]*/i)
    # exclude urls from being calculated when getting the words count
    urls.each { |url| txt.gsub!(url, ' ') } if urls.any?
    txt.split_text
  end

  def split_text
    self.dup.force_encoding('BINARY').split(/[,.:;?!\/\s]+/).reject(&:blank?)
  end

  def asian?
    # @ToDo this has a bug, it considerate latin strings with ’ as japanese,
    # breaking up the word count

    overlaps_cjk?(unpack('U*'))
  end

  def count_words
    if asian?
      (length / UTF8_ASIAN_WORDS).ceil
    else
      split_text.length
    end
  end

  # Remove non utf-8 chars (experimental, not sure how it behaves with other languages)
  def strip_non_utf8
    Iconv.iconv('utf-8//ignore//translit', 'utf-8', gsub(/\xC2/n, '')).to_s
  end

  def strip_html_tags
    ActionView::Base.full_sanitizer.sanitize(self.delete("\n").delete("\t").delete(8203.chr)).strip
  end
end

String.class_eval do
  prepend StringExtensions

  private

  CJK_CODEPOINTS = [
    # Language codepoints: http://codepoints.net/basic_multilingual_plane

    # Extra languages
    (0x0B80..0x0BFF), # Tamil
    (0x0E00..0x0E7F), # Thai
    (0x0900..0x097F), # Hindi 1
    (0xA8E0..0xA8FF), # Hindi 2
    (0x00A0..0x50A7), # Punjabi

    # CJK Definition
    (0xAC00..0xD7A3), # Hangul Syllables
    (0x4E00..0x62FF), # CJK part 1
    (0x6300..0x77FF), # CJK part 2
    (0x7800..0x8CFF), # CJK part 3
    (0x8D00..0x9FFF), # CJK part 4
    (0x3400..0x4DBF), # CJK extension 1
    (0x20000..0x215FF), # CJK extension B part 1
    (0x21600..0x230FF), # CJK extension B part 2
    (0x23100..0x245FF), # CJK extension B part 3
    (0x24600..0x260FF), # CJK extension B part 4
    (0x26100..0x275FF), # CJK extension B part 5
    (0x27600..0x290FF), # CJK extension B part 6
    (0x29100..0x2A6DF), # CJK extension B part 7
    (0x2A700..0x2B73F), # CJK extension C
    (0x2B740..0x2B81F) # CJK extension D

  ].freeze
  def overlaps_cjk?(codepoints)
    # NOTE: include? should be substituted by cover? when migrate to ruby 1.9
    codepoints.each do |code|
      CJK_CODEPOINTS.each do |range|
        return true if range.include?(code)
      end
    end
    false
  end
end
