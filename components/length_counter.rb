module LengthCounter
  def txt_length

    cnt = 0
    char_cnt = 0

    for idx in 0..txt.length
      o = txt[idx]
      if cnt == 0
        # not inside multi-byte sequence
        if (o & 0x80) == 0
          char_cnt += 1
        elsif (o & 0xe0) == 0xc0
          cnt = 1
        elsif (o & 0xf0) == 0xe0
          cnt = 2
        elsif (o & 0xf8) == 0xf0
          cnt = 3
        end
      else
        cnt -= 1
        char_cnt += 1 if cnt == 0
      end
    end
    # count any mal-terminated characters
    char_cnt += 1 if cnt != 0
    char_cnt
  end

  def count_required_text(required_text, check_default_re, alternate_txt = nil)
    txt_ = alternate_txt ? alternate_txt : txt

    return {} if txt_.blank?

    res = {}

    # count the user entered required text
    w = [PLURAL_SEPARATOR]
    w += required_text.split(',') unless required_text.blank?

    w.each do |word_|
      # first, make sure that the word doesn't have any leading or trailing spaces
      word = word_.strip

      cnt = 0
      txt_.gsub(word) { |_p| cnt += 1 }
      res[word] = cnt if cnt > 0
    end

    # count the default required texts
    if check_default_re == 1
      [SOFTWARE_RE1, SOFTWARE_RE2, SOFTWARE_RE3].each do |re|
        txt_.gsub(re) do |p|
          res[p] = 0 unless res.key?(p)
          res[p] += 1
        end
      end
    end

    res
  end

  def required_text_position(alternate_txt = nil)
    txt_ = alternate_txt ? alternate_txt : txt

    return [] if txt_.blank?

    res = []

    # count the default required texts
    txt_.gsub(SOFTWARE_RE_COMBINED) do |p|
      res << p
    end

    res
  end

end
