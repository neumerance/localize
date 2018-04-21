require File.dirname(__FILE__) + '/../test_helper'

class MockRevision
  attr_accessor :id, :cms_request_id, :cms_request
  def initialize(id, cms_request_id = nil)
    @id = id
    @cms_request_id = cms_request_id
  end

  def [](attr)
    instance_variable_get "@#{attr}"
  end
end

class XmlReadTest < ActiveSupport::TestCase
  fixtures :languages, :users

  def test_create
    revision = MockRevision.new(15)
    english = languages(:English)
    stream = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/with_ignores/proj1.xml", 'rb')
    listener = XmlStreamListener.new(revision, [])
    parser = REXML::Parsers::StreamParser.new(stream, listener)

    parser.parse

    # puts "WORD COUNT"
    # listener.word_count.each { |lang, c1| c1.each { |stat, count| puts "#{lang.name}: #{stat} -> #{count}" } }

    assert listener.word_count[english.id]

    assert_equal 252, listener.word_count[english.id][WORDS_STATUS_NEW_CODE]
    assert_equal 44, listener.sentence_count[english.id][WORDS_STATUS_NEW_CODE]
    assert_equal 1, listener.document_count[english.id][WORDS_STATUS_NEW_CODE]
    assert_equal 24, listener.support_files.length

    stream.close
  end

  # TODO: fix XmlStreamListener and recheck
  skip def test_multi_languages
    english = languages(:English)
    german = languages(:German)
    french = languages(:French)
    spanish = languages(:Spanish)

    revision = MockRevision.new(321)
    # to_proc = ["multi_languages/test-with-images.xml", 13]
    to_proc = ['multi_languages/icanlocalize.xml', revision]
    stream = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/" + to_proc[0], 'rb')
    listener = XmlStreamListener.new(to_proc[1], [german.id, french.id, spanish.id], nil)
    parser = REXML::Parsers::StreamParser.new(stream, listener)
    parser.parse

    if false
      puts 'WORD COUNT'
      listener.word_count.each do |lang_id, c1|
        c1.each do |stat, count|
          lang = Language.find(lang_id)
          puts "#{lang.name}: #{WORDS_STATUS_TEXT[stat]} -> #{count}"
        end
      end
    end

    assert listener.word_count[english.id]

    assert_equal 3813, listener.word_count[english.id][WORDS_STATUS_NEW_CODE]
    assert_equal 3813, listener.word_count[german.id][WORDS_STATUS_NEW_CODE]
    assert_equal 3813, listener.word_count[french.id][WORDS_STATUS_NEW_CODE]
    assert_equal 212, listener.word_count[spanish.id][WORDS_STATUS_NEW_CODE]
    assert_equal 0, listener.word_count[spanish.id][WORDS_STATUS_MODIFIED_CODE] || 0

    stream.close
  end

  def test_change_revision
    stream = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/with_ignores/proj1.xml", 'rb')
    support_file_ids = { 355 => 100, 356 => 101, 357 => 102, 358 => 103 }
    listener = XmlRevisionChanger.new('Hotdog', 'veryfirst', 99, support_file_ids)
    parser = REXML::Parsers::StreamParser.new(stream, listener)
    parser.parse
    stream.close

    f = File.open("#{File.expand_path(Rails.root)}/test/output/rev_out.xml", 'wb')
    f.write(listener.result)
    f.close
  end

  def test_change_revision_x
    f = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/with_ignores/proj1.xml", 'rb')
    t = f.read
    f.close

    x = REXML::Document.new(t)
    x.elements.each('TA_project/ta_buffer/translation/sentences/ta_sentence/text_data/text') do |element|
      # puts element.attributes
      if element.attributes.key?('rev_id')
        element.attributes['rev_id'] = 99.to_s
      end
    end
    x.write("#{File.expand_path(Rails.root)}/test/output/rev_out.xml")
  end

  def test_second_revision
    english = languages(:English)
    german = languages(:German)
    french = languages(:French)
    spanish = languages(:Spanish)

    # to_proc = ["multi_languages/test-with-images.xml", 13]
    revision = MockRevision.new(40)
    to_proc = ['second_revision/CMS_project_38.xml', revision]
    stream = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/" + to_proc[0], 'rb')
    listener = XmlStreamListener.new(to_proc[1], [german.id, french.id, spanish.id], nil)
    parser = REXML::Parsers::StreamParser.new(stream, listener)
    parser.parse

    if false
      puts 'WORD COUNT'
      listener.word_count.each do |lang_id, c1|
        c1.each do |stat, count|
          lang = Language.find(lang_id)
          puts "#{lang.name}: #{WORDS_STATUS_TEXT[stat]} (#{stat})-> #{count}"
        end
      end
    end

    assert listener.word_count[english.id]

    assert_equal 507, listener.word_count[english.id][WORDS_STATUS_NEW_CODE]
    assert_equal 471, listener.word_count[spanish.id][WORDS_STATUS_DONE_CODE]
    assert_equal 36, listener.word_count[spanish.id][WORDS_STATUS_NEW_CODE]

    stream.close
  end

  def test_with_titles
    english = languages(:English)
    german = languages(:German)
    french = languages(:French)
    spanish = languages(:Spanish)

    revision = MockRevision.new(40)
    # to_proc = ["multi_languages/test-with-images.xml", 13]
    to_proc = ['second_revision/CMS_project_38_w_titles.xml', revision]
    stream = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/" + to_proc[0], 'rb')
    listener = XmlStreamListener.new(to_proc[1], [german.id, french.id, spanish.id], nil)
    parser = REXML::Parsers::StreamParser.new(stream, listener)
    parser.parse

    if false
      puts 'WORD COUNT'
      listener.word_count.each do |lang_id, c1|
        c1.each do |stat, count|
          lang = Language.find(lang_id)
          puts "#{lang.name}: #{WORDS_STATUS_TEXT[stat]} (#{stat})-> #{count}"
        end
      end
    end

    assert listener.word_count[english.id]

    assert_equal 514, listener.word_count[english.id][WORDS_STATUS_NEW_CODE]
    assert_equal 507, listener.word_count[spanish.id][WORDS_STATUS_DONE_CODE]
    assert_equal 7, listener.word_count[spanish.id][WORDS_STATUS_NEW_CODE]

    stream.close
  end

  def test_complete_version
    english = languages(:English)
    german = languages(:German)
    spanish = languages(:Spanish)

    # to_proc = ["multi_languages/test-with-images.xml", 13]
    to_proc = ['second_revision/CMS_project_38_w_titles.xml', '40'] # file, rev_id
    # to_proc = ["second_revision/story_to_test_revisions-2247.xml", 1408]
    stream = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/" + to_proc[0], 'rb')
    dat = stream.read
    stream.close

    vc = VersionCompleter.new(nil, nil)
    vc.read_data(dat)

    language_names = [german, spanish].collect(&:name)
    vc.complete_languages(language_names)

    user = users(:amir)

    project = Project.create!(name: 'proj', client_id: user.id, kind: TA_PROJECT)
    revision = Revision.create!(project_id: project.id, description: 'something', language_id: english.id, name: 'initial',
                                released: 1, kind: TA_PROJECT)

    version = ::Version.create!(chgtime: Time.now, description: 'Created by version completer', filename: 'debug_filename.xml',
                                size: 1, content_type: 'binary')
    version.revision = revision
    version.user = user
    assert version.save

    FileUtils.mkdir_p(File.dirname(version.full_filename))

    t = ''
    vc.write(t)
    # Replace the rev_id in the xta file with the mock revision to make XmlStramListener work
    t = t.gsub(to_proc[1].to_s, revision.id.to_s)

    # f = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/second_revision/completed_story_to_test_revisions-2247.xml",'wb')
    # f.write(t)
    # f.close()

    Zlib::GzipWriter.open(version.full_filename) do |gz|
      gz.write(t)
    end

    version.size = File.size(version.full_filename)
    version.save!

    assert version.update_statistics(user)

    version.reload

    stats = version.get_stats

    # calculate the statistics
    original_lang_id = revision.language_id

    translation_languages_ids = [german, spanish].collect(&:id)

    translation_languages_ids.each do |language_id|
      next unless (language_id != original_lang_id) && stats[STATISTICS_SENTENCES].key?(language_id)
      stt = stats[STATISTICS_SENTENCES][language_id]
      done_words = stats[STATISTICS_WORDS][language_id].key?(WORDS_STATUS_DONE_CODE) ? stt[WORDS_STATUS_DONE_CODE] : 0
      done_sentences = stt.key?(WORDS_STATUS_DONE_CODE) ? stt[WORDS_STATUS_DONE_CODE] : 0
      total_sentences = 0
      stt.each { |_status, count| total_sentences += count }
      # puts "Language.#{language_id}: done_sentences=#{done_sentences}, total_sentences=#{total_sentences}, done_words=#{done_words}"
      assert_equal done_sentences, total_sentences, "Not all sentences were completed. Total: #{total_sentences}, completed: #{done_sentences}"
    end

  end

  def test_empty_revision
    english = languages(:English)
    spanish = languages(:Spanish)

    revision = MockRevision.new(12)
    to_proc = ['Initial/new_revision_no_text.xml', revision]
    stream = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/" + to_proc[0], 'rb')
    listener = XmlStreamListener.new(to_proc[1], [spanish.id], nil)
    parser = REXML::Parsers::StreamParser.new(stream, listener)
    parser.parse

    if false
      puts 'WORD COUNT'
      listener.word_count.each do |lang_id, c1|
        c1.each do |stat, count|
          lang = Language.find(lang_id)
          puts "#{lang.name}: #{WORDS_STATUS_TEXT[stat]} (#{stat})-> #{count}"
        end
      end
    end

    assert listener.word_count[english.id]

    assert_equal 2, listener.word_count[english.id][WORDS_STATUS_NEW_CODE]
    assert_equal 2, listener.word_count[spanish.id][WORDS_STATUS_NEW_CODE]
    assert_equal nil, listener.word_count[english.id][WORDS_STATUS_DONE_CODE]
    assert_equal nil, listener.word_count[spanish.id][WORDS_STATUS_DONE_CODE]

    stream.close
  end

  def test_large
    french = languages(:French)
    german = languages(:German)
    stream = File.open("#{File.expand_path(Rails.root)}/test/fixtures/sample/large/year-end-2010.xml", 'rb')
    revision = MockRevision.new(21403)
    listener = XmlStreamListener.new(revision, [french.id], nil)
    parser = REXML::Parsers::StreamParser.new(stream, listener)
    parser.parse

    # puts "WORD COUNT"
    # listener.word_count.each { |lang, c1| c1.each { |stat, count| puts "Language.#{lang}: #{stat} -> #{count}" } }

    assert listener.word_count[french.id]

    # puts "German=>#{german.id}"
    # puts "French=>#{french.id}"

    assert_equal 8623, listener.word_count[german.id][WORDS_STATUS_NEW_CODE]
    assert_equal nil, listener.word_count[german.id][WORDS_STATUS_DONE_CODE]
    assert_equal nil, listener.word_count[french.id][WORDS_STATUS_NEW_CODE]

    stream.close
  end

end
