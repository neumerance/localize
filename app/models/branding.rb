class Branding < ApplicationRecord
  belongs_to :owner, polymorphic: true
  belongs_to :language

  MAX_SIZE = { logo_width: 600, logo_height: 150 }.freeze

  validates :logo_url, :home_url, :logo_width, :logo_height, presence: true
  validates :logo_url, :home_url, url_field: true

  validates_each :logo_width, :logo_height, allow_blank: false do |record, attr, value|
    record.errors.add(attr, _('must be a positive number')) if value <= 0
    record.errors.add(attr, _('cannot be larger than %d') % MAX_SIZE[attr]) if value > MAX_SIZE[attr]
  end

  def lang_div
    if language_id.blank?
      'BrandingDefault'
    else
      "Branding#{language_id}"
    end
  end

  def title
    if language_id.blank?
      _('Default appearance')
    else
      _('Appearance for %s') % language.name
    end
  end

end
