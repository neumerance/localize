module Rumoji
  def encode(str)
    Rumoji.encode_string(str)
  rescue StandardError => ex
    Logging.log_error(self, ex)
    Rumoji.encode_string(str.encode('utf-8'))
  end

  def self.encode_string(str)
    str.gsub(Emoji::ALL_REGEXP) do |match|
      emoji = Emoji.find_by_string(match)
      if emoji
        # Our DB currently support emojis of only 3 bytes length
        if emoji.string.bytes.count <= 3
          match
        elsif block_given?
          yield emoji
        else
          emoji.code
        end
      else
        match
      end
    end
  end
end
