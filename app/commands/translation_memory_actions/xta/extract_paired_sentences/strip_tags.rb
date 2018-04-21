module TranslationMemoryActions
  module Xta
    class ExtractPairedSentences
      class StripTags
        TAG = /<[^>]+>/
        TAG_NAME = %r{<\/?([^>\s]+)}

        def call!(parsed_sentences)
          parsed_sentences.each do |parsed_sentence|
            parsed_sentence[:original] = strip_root_tag!(parsed_sentence[:original])
            parsed_sentence[:target] = strip_root_tag!(parsed_sentence[:target]) if parsed_sentence[:target]
          end
        end

        private

        def strip_root_tag!(html)
          tags = html.scan(TAG).map do |tag|
            OpenStruct.new(
              tag: tag,
              name: tag.scan(TAG_NAME).join,
              self_closing: tag.end_with?('/>'),
              closing: tag.start_with?('</')
            )
          end
          return html if tags.size < 2
          return html unless possible_global_root?(tags, html)

          (global_root?(tags) ? strip_root_tag(html, tags) : html).strip
        end

        def possible_global_root?(tags, html)
          start_tag = tags.first
          end_tag = tags.last

          start_tag.name == end_tag.name &&
            !start_tag.closing && end_tag.closing &&
            html.start_with?(start_tag.tag) && html.end_with?(end_tag.tag)
        end

        def global_root?(tags)
          stack = []

          tags.each_with_index do |tag_item, index|
            next if tag_item.self_closing

            if tag_item.closing
              last_opened_tag = stack.last&.name.to_s
              stack.pop if last_opened_tag == tag_item.name
            else
              stack << tag_item
            end

            return false if stack.empty? && index < (tags.size - 1)
          end

          stack.empty?
        end

        def strip_root_tag(html, tags)
          start_tag = tags.first
          end_tag = tags.last

          html[start_tag.tag.size...-end_tag.tag.size]
        end
      end
    end
  end
end
