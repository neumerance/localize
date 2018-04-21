#   content_type:
#     atomic: [shortcode]
#     openclose: [shortcode]some <br> content[/shortcode] (just the shortcodes)
#     openclose-exclude: OpenClose exclude also content
class Shortcode < ApplicationRecord
  belongs_to :website
  belongs_to :creator, class_name: 'User', foreign_key: :created_by

  default_scope { order('shortcode') }

  scope :global, -> { where(website_id: nil) }
  scope :enabled, -> { where(enabled: true) }

  CONTENT_TYPE_OPTIONS = %w(atomic openclose openclose-exclude).freeze
  CONTENT_TYPE_NAMES = ['Atomic', 'Open and close', 'Open, exclude and close'].freeze

  validates_inclusion_of :content_type, in: CONTENT_TYPE_OPTIONS,
                                        message: '{{value}} is not a valid shortcode type'
  validates_uniqueness_of :shortcode, scope: :website_id

  validates :comment, length: { maximum: COMMON_FIELD }

  def enabled?(website_id = nil)
    website_id ? enabled_for_website?(website_id) : enabled
  end

  def enabled_for_website?(target_website_id)
    return enabled if website_id

    ws = WebsiteShortcode.where(website_id: target_website_id, shortcode_id: id).first
    ws ? ws.enabled : enabled
  end

  def global?
    !website_id
  end

  def atomic?
    'atomic' == content_type
  end

  def openclose?
    'openclose' == content_type
  end

  def openclose_exclude?
    'openclose-exclude' == content_type
  end

  def toggle_enabled
    update_attribute :enabled, !enabled?
  end

  def self.create_from_array(array, content_type)
    data = { enabled: true, content_type: content_type }

    array.each do |tag|
      shortcode = Shortcode.new(data)
      shortcode.shortcode = tag
      shortcode.save
    end
  end

end
