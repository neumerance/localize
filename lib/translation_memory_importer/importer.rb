# This is to be used to import existing TM when WebTA is launched
module TranslationMemoryImporter
  class Importer
    attr_writer :logger

    def initialize(start: 1, size: 100, path: 'log/tm_importer.log')
      @start = start
      @size = size
      @logger = Logger.new(path)
      @batch_start = Time.now
    end

    def import_in_production
      @logger.info("Started processing at: #{Time.now} with record #{@start} and batch size of #{@size}")
      ids = CmsRequest.where('xliff_processed = ? and id > ?', false, @start).order('id desc').pluck(:id)
      ids.each_slice(@size) do |chunk|
        group = CmsRequest.find(chunk)
        @batch_start = Time.now
        @logger.info("Started a batch of #{@size} at #{@batch_start} with record #{group.first.try(:id)}")
        group.each do |cms|
          begin
            parse_cms_for_webta(cms)
          rescue => e
            @logger.error("TM importing stopped at #{cms.id} with error: #{e.inspect}, #{e.message}, #{e.backtrace[0]}")
          end
        end
        @logger.info("Finished a batch of #{@size} at #{Time.now}, in #{Time.now - @batch_start} with record #{group.last.try(:id)}")
      end
    end

    def fix_px
      @log = Logger.new("#{Rails.root}/log/fix_px.log")
      CmsRequest.where('xliff_processed=? and id > ?', true, 100000).find_each do |cms|
        begin
          bx = cms.base_xliff # what to do if  bx is nil?
          next if bx.nil? || bx.try(:parsed_xliffs).present?
          px = cms.translated_xliff.try(:parsed_xliff)
          if px.present?
            # we need to move it to base_xliff
            px.update_attribute(:xliff_id, bx.id)
            @log.info("UPDATED cms: #{cms.id}")
          else
            # something is wrong, we need need to update cms to not processed
            cms.update_attribute(:xliff_processed, false)
            @log.info("REVERTED cms: #{cms.id}")
          end
        rescue => e
          @log.error("ERROR cms: #{cms.id} error: #{e.inspect}")
        end
      end
    end

    def start
      @logger.info("Started processing at: #{Time.now} with record #{@start} and batch size of #{@size}")

      scope = CmsRequest.joins(:xliffs).where('status=? and translated=?', CMS_REQUEST_DONE, true)
      scope = scope.where('cms_requests.id > ?', @start)

      CmsRequest.where(status: CMS_REQUEST_DONE).find_in_batches(start: @start, batch_size: @size) do |group|
        @batch_start = Time.now
        @logger.info("Started a batch of #{@size} at #{@batch_start} with record #{group.first.try(:id)}")
        Parallel.each(group, in_processes: 10) do |cms|
          begin
            # tms = import(cms)
            # Checker.new(cms).compare_with_xliff(tms)
            # first check if the translated xliff exists locally. if not, we will fetch it from production server
            begin
              if cms.translated_xliff
                cms.translated_xliff.get_contents
              else
                @logger.info("---[v2][imp][NO_FILE][cms_id=#{cms.id}]")
              end
            rescue Errno::ENOENT => _ex
              FileFetcher.fetch_from_production(cms, @logger)
            end
            import_tm_from_xliff(cms)
          rescue => e
            @logger.error("TM importing stopped at #{cms.id} with error: #{e.inspect}, #{e.message}, #{e.backtrace[0]}")
          end
        end
        @logger.info("Finished a batch of #{@size} at #{Time.now}, in #{Time.now - @batch_start} with record #{group.last.try(:id)}")
      end

    end

    def structure_stats
      scope = CmsRequest.joins(:xliffs).where('status=? and translated=?', CMS_REQUEST_DONE, true)
      scope.find_in_batches(start: @start, batch_size: @size) do |group|
        @batch_start = Time.now
        @logger.info("Started a batch of #{@size} at #{@batch_start} with record #{group.first.id}")
        Parallel.each(group, in_processes: 15) do |cms|
          begin
            begin
              cms.translated_xliff.get_contents
            rescue Errno::ENOENT => ex
              FileFetcher.fetch_from_production(cms, @logger)
            end
            structure_stats_for_xliff(cms)
          rescue => e
            @logger.error("TM Stats stopped at #{cms.id} with error: #{e.inspect}, #{e.message}, #{e.backtrace[0]}")
          end
        end
        @logger.info("Finished a batch of #{@size} at #{Time.now}, in #{Time.now - @batch_start} with record #{group.last.id}")
      end
    end

    alias resume start

    def structure_stats_for_xliff(cms)
      SourceStats.new(cms.id).fetch(logger: @logger)
    end

    def parse_cms_for_webta(cms)
      if cms.status == CMS_REQUEST_TRANSLATED || cms.status == CMS_REQUEST_DONE
        return unless cms.translated_xliff.present?
        # trying to read contents just to raise error in case xliff is not present and not trigger a DJ
        cms.translated_xliff.get_contents
        Delayed::Job.enqueue(ImportJob.new(cms.translated_xliff, true), priority: 5)
      else
        return unless cms.base_xliff.present?
        # trying to read contents just to raise error in case xliff is not present and not trigger a DJ
        cms.base_xliff.get_contents
        Delayed::Job.enqueue(ImportJob.new(cms.base_xliff, false), priority: 5)
      end
    end

    def import_tm_from_xliff(cms = nil, save = true)
      translated_xliff = cms.translated_xliff
      return unless translated_xliff.present?
      # content = FileFetcher.new(translated_xliff.full_filename, translated_xliff.filename).fetch
      content = translated_xliff.get_contents
      xml = Nokogiri::XML(Otgs::Segmenter.parsed_xliff(content))
      source_sentences = xml.css('seg-source mrk')
      target_sentences = xml.css('target mrk')

      if source_sentences.size != target_sentences.size
        @logger.error("---[v2][imp][ERROR][cms_id=#{cms.id}][source=#{source_sentences.size}][target=#{target_sentences.size}]")
        SourceStats.new(cms.id).fetch(source: 'seg-source', target: 'target', logger: @logger)
      else
        untranslated = target_sentences.select { |x| x.attribute('mstatus').value == '-2' }.size
        invalid_translations = target_sentences.select { |x| x.attribute('mstatus').value == '-3' }.size
        translated = target_sentences.select { |x| x.attribute('mstatus').value == '-1' }.size
        total = translated + untranslated + invalid_translations
        rate = ((translated + untranslated) * 100 / total.to_f).round

        details = "[translated=#{translated}][untranslated=#{untranslated}][invalid=#{invalid_translations}]"
        @logger.info("---[v2][imp][OK][cms_id=#{cms.id}][total=#{total}][rate=#{rate}]#{details}")

        begin
          if save
            ParsedXliff.create_parsed_xliff_by_id(translated_xliff.id, true)
            @logger.info("---[v2][imp][SAVED][cms_id=#{cms.id}]")
          end
        rescue => e
          @logger.error("---[v2][imp][ERROR][cms_id=#{cms.id}] ERROR when creating parsed xliff: #{e.message}, #{e.backtrace[0]}")
        end
      end
    rescue StandardError => ex
      @logger.error("---[v2][imp][EXCEPTION][cms_id=#{cms.id}][error=#{ex.message}]")
    end

    def parse_and_save(id)
      CmsRequest.find(id)
      translated_xliff = cms.translated_xliff
      ParsedXliff.create_parsed_xliff_by_id(translated_xliff.id)
    end

    def import(cms = nil)
      if cms.present?
        translated_version = cms.revision.versions.last
        content = FileFetcher.new(translated_version.full_filename, translated_version.filename).fetch
      else
        cms = CmsRequest.find 150089 if cms.blank?
        content = File.read("#{Rails.root}/spec/fixtures/files/xta/test.xta")
      end
      tms = XtaParser.new(content).prepare_tms
      save_to_db(tms, cms.website.client, cms.cms_target_language.translator) if to_be_saved.present?
      tms
    end

    def save_to_db(tms, client, translator)
      tms.each do |tm|
        source_language = Language.find_by_name(tm[:original][:language])
        target_language = Language.find_by_name(tm[:translated][:language])
        existing_tm = TranslationMemory.where(signature: tm[:original][:signature_xliff], language_id: source_language.id, client_id: client.id).first
        unless existing_tm
          existing_tm = TranslationMemory.new
          existing_tm.client = client
          existing_tm.language = source_language
          existing_tm.signature = tm[:original][:signature_xliff]
          existing_tm.raw_signature = tm[:original][:signature_raw]
          existing_tm.content = tm[:original][:xliff_text]
          existing_tm.raw_content = tm[:original][:raw_text]
          existing_tm.word_count = Processors::WordCounter.count_words(tm[:original][:raw_text], source_language)
          existing_tm.save!
        end
        translated_memory = existing_tm.translated_memories.where(language: target_language).last
        next if translated_memory.present?
        translated_memory = TranslatedMemory.new
        translated_memory.client = client
        translated_memory.language = target_language
        translated_memory.translation_memory = existing_tm
        translated_memory.content = tm[:translated][:xliff_text]
        translated_memory.raw_content = tm[:translated][:raw_text]
        translated_memory.translator = translator
        translated_memory.save!
      end
    end

    # utility method for db importing
    def self.clean_import
      ParsedXliff.delete_all
      XliffTransUnit.delete_all
      XliffTransUnitMrk.delete_all
      TranslationMemory.delete_all
      TranslatedMemory.delete_all
      CmsRequest.update_all(xliff_processed: false)
      Xliff.update_all(processed: false)
    end
  end
end
