class Keyword < ApplicationRecord
  belongs_to :purchased_keyword_package
  has_one :keyword_project, through: :purchased_keyword_package
  has_many :keyword_translations
  has_many :translations, -> { where(category: KeywordTranslation::TRANSLATION) }, class_name: 'KeywordTranslation'
  has_many :alternatives, -> { where(category: KeywordTranslation::ALTERNATIVE) }, class_name: 'KeywordTranslation'

  PENDING_TRANSLATION = 0
  TRANSLATED = 1

  def pending?
    status == PENDING_TRANSLATION
  end

  def filled?
    reload
    keyword_translations.any? && !result.blank?
  end

  def save_progress(data)
    transaction do
      keyword_translations.delete_all

      unless data.blank?
        unless data[:translations].blank?
          data[:translations].delete_if { |x| x[:text].blank? }
          KeywordTranslation.create(
            data[:translations].map do |trans|
              trans[:hits].gsub!(/,|\.| /, '')
              trans.merge(category: KeywordTranslation::TRANSLATION, keyword_id: id)
            end
          )
        end

        unless data[:terms].blank?
          data[:terms].delete_if { |x| x[:text].blank? }
          KeywordTranslation.create(
            data[:terms].map do |trans|
              trans[:hits].gsub!(/,|\.| /, '')
              trans.merge(category: KeywordTranslation::ALTERNATIVE, keyword_id: id)
            end
          )
        end

        if data[:result].blank?
          update_attribute :result, nil
        else
          update_attribute :result, data[:result]
        end
      end
    end
  end
end
