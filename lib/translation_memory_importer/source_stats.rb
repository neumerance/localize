module TranslationMemoryImporter
  class SourceStats

    def initialize(id)
      @id = id
    end

    def fetch(source: 'source', target: 'target', logger:)
      cms = CmsRequest.find(@id)
      translated_xliff = cms.translated_xliff
      content = FileFetcher.new(translated_xliff.full_filename, translated_xliff.filename).fetch
      xml = doc(content)

      sources = xml.search(source)
      targets = xml.search(target)

      ok = 0
      er = 0

      sources.each_with_index do |source_item, i|
        target = targets[i]

        sn = nodes_list(source_item.content)
        tn = nodes_list(target.content)

        d = Diffy::Diff.new(sn, tn)
        diff = d.to_s.split("\n").select { |x| x.start_with?('+', '-') }

        if diff.empty?
          ok += 1
        else
          logger.error diff.map { |l| "---[v2][stats][diff][cms_id=#{cms.id}]#{l}" }.join("\n")
          er += 1
        end
      end

      status = er.zero? ? 'EQUAL' : 'WRONG'
      msg = "---[v2][stats][result][#{status}][cms_id=#{cms.id}][ok=#{ok}][er=#{er}]"

      logger.info(msg)

      nil
    end

    def nodes_list(content)
      doc = source_doc(content)
      n = []

      process_nested_nodes(doc) do |node|
        nodes = node.children.map(&:name).reject { |x| x == 'text' }.sort.join(',')
        n << "#{node.parent.name}->#{node.name}->[#{nodes}]"
      end

      n.join("\n")
    end

    def source_doc(content)
      html = "<html>#{remove_html_entities(content)}</html>"
      doc(html).children.first
    end

    def doc(xml)
      Nokogiri::XML(xml)
    end

    def process_nested_nodes(nested_node, &blk)
      yield nested_node, nested_node.children
      nested_node.children.each { |child_node| process_nested_nodes(child_node, &blk) }
    end

    def remove_html_entities(text)
      text.gsub('&gt;', '>').gsub('&lt;', '<')
    end
  end
end
