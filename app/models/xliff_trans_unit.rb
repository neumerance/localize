class XliffTransUnit < ApplicationRecord

  belongs_to :parsed_xliff
  belongs_to :source_language, class_name: Language
  belongs_to :target_language, class_name: Language

  has_many :xliff_trans_unit_mrks, dependent: :destroy

  def source_mrks
    mrks.where(mrk_type: XliffTransUnitMrk::MRK_TYPES[:source]).order(:id)
  end

  def target_mrks
    mrks.where(mrk_type: XliffTransUnitMrk::MRK_TYPES[:target]).order(:id)
  end

  def loaded_source_mrks
    loaded_mrks.select { |x| x.mrk_type == XliffTransUnitMrk::MRK_TYPES[:source] }.sort_by(&:id)
  end

  def loaded_target_mrks
    loaded_mrks.select { |x| x.mrk_type == XliffTransUnitMrk::MRK_TYPES[:target] }.sort_by(&:id)
  end

  def loaded_mrks
    @loaded_mrks ||= mrks.to_a
  end

  def mrks
    xliff_trans_unit_mrks
  end
end
