module IclHelpers
  class Common
    class << self
      def calculate_signature(content)
        Digest::MD5.hexdigest(content)
      end

      def calculate_raw_signature(content)
        Digest::MD5.hexdigest(raw(content))
      end

      def raw(html)
        html.gsub(/<.*?>/, '').gsub(/\s+/, ' ').strip
      end
    end
  end
end
