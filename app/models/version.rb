# 	This is an XTA file provided by TAS
#
# 	status:
#
class Version < ZippedFile
  belongs_to :revision, foreign_key: :owner_id
  belongs_to :user, foreign_key: :by_user_id
  has_many :statistics, dependent: :destroy
  has_many :tus, as: :owner, dependent: :destroy

  include ParentWithSiblings

  # return list of siblings
  def siblings
    []
  end

  def can_delete_me
    true
  end

  def update_sisulizer_statistics
    xml = attachment_data

    listener = SisulizerScanner.new(logger)
    parser = REXML::Parsers::StreamParser.new(xml, listener)
    parser.parse

    listener.fixup_count

    orig_language = listener.orig_language

    listener.word_count.each do |to_lang, stats|
      stats.each do |status, word_count|
        statistic = Statistic.new(stat_code: STATISTICS_WORDS,
                                  language_id: orig_language.id,
                                  dest_language_id: to_lang.id,
                                  status: status,
                                  count: word_count)
        statistic.version = self
        statistic.save!
      end
    end

    GC.start

    [orig_language, listener.word_count]
  end

  def update_statistics(user = nil)
    Rails.logger.info 'Version Updating Statistics...'
    start_time = Time.now
    user = revision.project.client unless user

    unzipped_contents = get_contents
    # logger.info("==>\n#{unzipped_contents}\n")
    Rails.logger.info("==> length #{unzipped_contents.length}")

    # check that the file is a GZIP file
    if unzipped_contents.nil?
      Rails.logger.info('==> !!! unzipped_contents is nil, aborting update_statistics!')
      return false
    end

    # for clients only, parse the project and:
    #   1) Get project statistics
    #   2) Update the support files used
    stats_languages =
      if revision.cms_request
        revision.cms_request.cms_target_languages.collect(&:language_id)
      else
        revision.revision_languages.collect(&:language_id)
      end

    listener = XmlStreamListener.new(revision, stats_languages, logger)
    parser = REXML::Parsers::StreamParser.new(unzipped_contents, listener)
    parser.parse

    # verify that there is at least one language in this version, otherwise, return an error status
    # if (listener.word_count.keys().length == 0) ||
    #	(listener.sentence_count.keys().length == 0) ||
    #	(listener.document_count.keys().length == 0)
    #	return false
    # end

    docs_stats = {
      STATISTICS_WORDS 	   => listener.word_count,	# 3
      STATISTICS_SENTENCES => listener.sentence_count,	# 2
      STATISTICS_DOCUMENTS => listener.document_count 	# 1
    }

    # make sure we're clearing any old statistics for this version
    statistics.delete_all

    # create an entry for every attribute
    docs_stats.each do |stats_code, stats_val|
      stats_val.each do |lang_id, c1|
        c1.each do |status, count|
          # if stats_code == STATISTICS_WORDS
          #	puts "Creating stat: language_id=#{lang_id}, status=#{status}, count=#{count}"
          # end
          statistic = Statistic.new(stat_code: stats_code,
                                    language_id: lang_id,
                                    status: status,
                                    count: count)
          statistic.version = self
          statistic.save!
        end
      end
    end

    listener.support_files_to_translate.each do |lang_id, c1|
      c1.each do |status, count|
        statistic = Statistic.new(stat_code: STATISTICS_SUPPORT_FILES,
                                  language_id: lang_id,
                                  status: status,
                                  count: count)
        statistic.version = self
        statistic.save!
      end
    end

    client = revision.project.client
    # populate the translation memory from the parse
    listener.tm_entries.each do |key, entry|
      # signature, from_language_id, to_language_id => orig, translation, status, need_update
      tu = Tu.where('(client_id=?) AND (signature=?) AND (from_language_id=?) AND (to_language_id=?)', client.id, key[0], key[1], key[2]).first
      if !tu
        tu = Tu.new(original: entry[0],
                    translation: entry[1],
                    signature: key[0],
                    from_language_id: key[1], to_language_id: key[2],
                    status: entry[2])
        tu.client = revision.project.client
        tu.translator = user[:type] == 'Translator' ? user : nil
        tu.owner = self
        tu.save
      elsif entry[2] == TU_COMPLETE
        tu.update_attributes(status: TU_COMPLETE,
                             translation: entry[1],
                             translator_id: (user[:type] == 'Translator' ? user.id : nil))
      end
    end

    if user == revision.project.client
      support_files = listener.support_files
      if listener.original_languages.length == 1
        revision.language = listener.original_languages[0]
        revision.save!
      end
      revision.update_support_files(support_files)
    end

    # make sure the version knows it has statistics
    reload

    # If this is a cms request update statistics on the cms_target_language
    # Note: this code was on cms_request_controller after update_statistics is called
    # 	But if the statistics are updated from console then the cms_target_language doesnt get updated.
    if revision
      revision.cms_request&.cms_target_languages&.each do |cms_target_language|
        wc = revision.lang_word_count(cms_target_language.language)
        cms_target_language.word_count = wc # docs_stats[STATISTICS_WORDS]
        cms_target_language.save!
      end
    end

    Rails.logger.info "Update Statistics Time elapsed: #{Time.now - start_time}"

    true
  end

  def add_to_tm
    unzipped_contents = get_contents
    # logger.info("==>\n#{unzipped_contents}\n")

    # check that the file is a GZIP file
    return false if unzipped_contents.nil?

    # for clients only, parse the project and:
    # 1) Get project statistics
    # 2) Update the support files used
    listener = XmlStreamListener.new(revision.id, revision.revision_languages.collect { |rl| rl.language.id }, logger)
    parser = REXML::Parsers::StreamParser.new(unzipped_contents, listener)
    parser.parse

    client = revision.project.client

    listener.tm_entries.each do |key, entry|
      # signature, from_language_id, to_language_id => orig, translation, status, need_update
      tu = Tu.where('(client_id=?) AND (signature=?) AND (from_language_id=?) AND (to_language_id=?)', client.id, key[0], key[1], key[2]).first
      if !tu
        tu = Tu.new(original: entry[0],
                    translation: entry[1],
                    signature: key[0],
                    from_language_id: key[1], to_language_id: key[2],
                    status: entry[2])
        tu.client = revision.project.client
        tu.translator = user[:type] == 'Translator' ? user : nil
        tu.owner = self
        tu.save
      elsif entry[2] == TU_COMPLETE
        tu.update_attributes(status: TU_COMPLETE,
                             translation: entry[1],
                             translator_id: (user[:type] == 'Translator' ? user.id : nil))
      end
    end

    true
  end

  def get_stats
    stats = {}
    statistics.each do |stat|
      stats[stat.stat_code] = {} unless stats.key?(stat.stat_code)
      stats[stat.stat_code][stat.language_id] = {} unless stats[stat.stat_code].key?(stat.language_id)
      stats[stat.stat_code][stat.language_id][stat.status] = stat.count
    end
    stats
  end

  def get_human_stats

    stats_codes = {
      0  => :done,
      1  => :new,
      2  => :modified
    }

    stats = get_stats
    new_stats = {}

    new_stats[:documents] 		= stats[STATISTICS_DOCUMENTS] if stats.key? STATISTICS_DOCUMENTS
    new_stats[:sentences] 		= stats[STATISTICS_SENTENCES] if stats.key? STATISTICS_SENTENCES
    new_stats[:words]	= stats[STATISTICS_WORDS] if stats.key? STATISTICS_WORDS
    new_stats[:support_files] = stats[STATISTICS_SUPPORT_FILES] if stats.key? STATISTICS_SUPPORT_FILES

    new_stats.each do |code, s|
      s.each do |language_id, st|
        next if language_id.is_a? String

        st.each do |status_code, _count|
          next if status_code.is_a? Symbol
          if stats_codes.key? status_code
            st[stats_codes[status_code]] = st.delete status_code
          end
        end

        new_stats[code][Language.find(language_id).name] = new_stats[code].delete language_id
      end
    end

    new_stats
  end

  def get_sisulizer_stats
    stats = {}
    orig_language = nil
    statistics.each do |stat|
      orig_language = stat.language
      stats[stat.dest_language] = {} unless stats.key?(stat.dest_language)
      stats[stat.dest_language][stat.status] = stat.count
    end
    [orig_language, stats]
  end

  def translation_languages
    chat = revision.chats.find_by(translator_id: user.id)
    return [] unless chat
    revision.revision_languages.joins(:bids).where('(bids.chat_id=?) AND (bids.won=1)', chat.id).map(&:language)
  end

  def debug_print_statistics
    logger.info ' ---- debug_print_statistics ----'
    statistics.each do |stat|
      logger.info "---- stat_code: #{stat.stat_code} / language: #{stat.language.name}, status: #{stat.status}, count: #{stat.count}"
    end
  end

  def set_contents(plain_contents)
    FileUtils.mkdir_p(File.dirname(full_filename))

    Zlib::GzipWriter.open(full_filename) do |gz|
      gz.write(plain_contents)
    end

    self.size = File.size(full_filename)
    save!
  end
end
