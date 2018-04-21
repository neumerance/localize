class XliffTransUnitMrk < ApplicationRecord

  belongs_to :xliff_trans_unit
  belongs_to :language
  belongs_to :translation_memory
  belongs_to :translated_memory
  belongs_to :translators_translation_memory
  belongs_to :translators_translated_memory
  has_many :issues, as: :owner
  # those are redundant only for reporting purposes later
  belongs_to :xliff
  belongs_to :cms_request
  belongs_to :client

  # acts_as_paranoid

  MRK_TYPES = {
    source: 0,
    target: 1
  }.freeze

  MRK_STATUS = {
    original: 0,
    in_progress: 1,
    translation_completed: 2,
    completed_from_tm: 3,
    review_in_progress: 4,
    completed: 5
  }.freeze

  scope :translation_completed, lambda {
    where(mrk_status: XliffTransUnitMrk::MRK_STATUS[:translation_completed])
  }

  def source_mrk
    return nil unless self.mrk_type == MRK_TYPES[:target]
    XliffTransUnitMrk.find_by_id self.source_id
  end

  def target_mrk
    return nil unless self.mrk_type == MRK_TYPES[:source]
    XliffTransUnitMrk.find_by_id self.target_id
  end

  def target?
    self.mrk_type == MRK_TYPES[:target]
  end

  def source?
    self.mrk_type == MRK_TYPES[:source]
  end

  UNTRANSLATABLE_VALUES = %w(no-sidebar true false default).freeze

  def untranslatable?
    return true if self.content.nil?
    self.content.strip_html_tags.size == 0 ||
      UNTRANSLATABLE_VALUES.include?(self.content) ||
      (self.content =~ /^\d+$/)
  end

  def translatable?
    !untranslatable?
  end

  def markers_stats(html)
    doc = Nokogiri::XML("<root>#{html}</root>")
    selectors = %w(g x)
    nodes = doc.css('*').select { |x| selectors.include?(x.name) }

    other_node_names = doc.css('*').map(&:name).reject { |x| (selectors + ['root']).include?(x) }

    optional_keys = %w(sup)

    nodes.reject! do |x|
      optional_keys.include?(x.attributes['ctype']&.value.to_s.split('x-html-').last)
    end

    stats = nodes.map do |x|
      [
        x.attributes['ctype'].value,
        x.attributes['id'].value
      ].join('__')
    end

    { stats: stats.sort, other_nodes: other_node_names }
  end

  def content_marker_stats
    markers_stats(self.content)
  end

  def source_markers_stats
    markers_stats(self.source_mrk.content)
  end

  def has_all_markers?
    return true if self.mrk_type == MRK_TYPES[:source]
    content_marker_stats == source_markers_stats
  end

  def update_status(status)
    return unless MRK_STATUS.values.include?(status)
    self.top_content = self.top_content.sub(/(?<=mstatus=")\d/, status.to_s)
    self.mrk_status = status
    self.save!
    source = self.source_mrk
    return unless source
    source.top_content = source.top_content.sub(/(?<=mstatus=")\d/, status.to_s)
    source.mrk_status = status
    source.save!
  end

  def get_word_count
    Processors::WordCounter.count(content, language.count_method, language.ratio)
  end

  def unit
    xliff_trans_unit
  end
end
