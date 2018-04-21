class ParsedXliff < ApplicationRecord

  belongs_to :xliff
  belongs_to :client
  belongs_to :cms_request
  belongs_to :website
  belongs_to :source_language, class_name: Language
  belongs_to :target_language, class_name: Language

  has_many :xliff_trans_units, dependent: :destroy
  has_many :xliff_trans_unit_mrks, through: :xliff_trans_units

  # When self.tm_word_count changes, update the corresponding
  # cms_target_language.word_count
  before_save :update_ctl_word_count, if: -> { attribute_changed?(:tm_word_count) }

  class << self
    def create_parsed_xliff_by_id(xliff_id, force_import = false)
      create_parsed_xliff(xliff_id, force_import)
    end

    def create_parsed_xliff(xliff_id, force_import = false)
      TranslationMemoryActions::PopulateTranslatedMemory.new.call(cms_request: Xliff.find(xliff_id).cms_request)
      CmsActions::Parsing::CreateParsedXliff.new.call(xliff_id: xliff_id, force_import: force_import)
    end

    handle_asynchronously :create_parsed_xliff_by_id, priority: 5, queue: 'process_xliff'
  end

  def recreate_original_xliff
    Otgs::Segmenter::XLIFFMerger.new(self.full_xliff).get_original_xliff
  end

  def full_xliff(with_dbid = false)
    xliff = ''
    xliff << self.top_content
    xliff << self.header
    xliff << '<body>'
    self.xliff_trans_units.includes(:xliff_trans_unit_mrks).each do |xtu|
      xliff << xtu.top_content
      xliff << xtu.source
      xliff << '<seg-source>'
      xtu.loaded_source_mrks.each do |mrk|
        xliff << mrk.top_content
        xliff << mrk.content
        xliff << mrk.bottom_content
      end
      xliff << '</seg-source>'
      xliff << '<target>'
      xtu.loaded_target_mrks.each do |mrk|
        xliff << if with_dbid
                   mrk.top_content.split('>').first.concat(" dbid=\"#{mrk.id}\" >")
                 else
                   mrk.top_content
                 end
        xliff << mrk.content
        xliff << mrk.bottom_content
      end
      xliff << '</target>'
      xliff << xtu.bottom_content
    end
    xliff << '</body>'
    xliff << self.bottom_content
    xliff
  end

  def all_mrk_completed?(which = 'translation')
    base_status = which == 'translation' ? XliffTransUnitMrk::MRK_STATUS[:in_progress] : XliffTransUnitMrk::MRK_STATUS[:translation_completed]
    XliffTransUnitMrk.where(xliff_id: self.xliff.id, mrk_type: XliffTransUnitMrk::MRK_TYPES[:target]).size == XliffTransUnitMrk.where('xliff_id = ? and mrk_type = ? and mrk_status > ?', self.xliff.id, XliffTransUnitMrk::MRK_TYPES[:target], base_status).size
  end

  def updated_recently?
    last_updated_time = xliff_trans_unit_mrks.map(&:updated_at).last
    last_updated_time >= recent_threshold_time
  end

  def recent_threshold_time
    Time.now - 2.days
  end

  def units
    xliff_trans_units
  end

  def mrks
    xliff_trans_unit_mrks
  end

  private

  # Update cms_target_language.word_count, which is the word count used to
  # calculate the price of a CmsRequest. Ensure words that are in TM
  # (Translation Memory) are not included in the price (they should not be
  # charged from the client or paid to the translator).
  #
  # - self.tm_word_count is calculate by the otgs-segmenter gem and consists of
  #   the word count after TM is apllied (total words - words translated by TM)
  # - cms_target_language.word_count is calculated by TAS and is also supposed
  #   to be the word_count after TM is applied, but it doesn't take TM into
  #   account in WebTA projects. That's why this method is necessary.
  def update_ctl_word_count
    # If tm_word_count == word_count, it means TM was not applied by WebTA, so
    # there is no need to update cms_target_language.word_count
    return if self.tm_word_count == self.word_count

    correct_word_count = [
      self.tm_word_count,
      self.cms_request&.cms_target_language&.word_count
    ].compact.min || 0

    self.cms_request.cms_target_language.update(word_count: correct_word_count)
  end
end
