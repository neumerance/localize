class WebsiteQuote
  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming
  attr_accessor :url

  validates_presence_of :url
  validate :validate_url

  def initialize(url = nil)
    return unless url
    self.url = url
    self.validate!
  end

  def get_words
    %x(curl "#{self.url}" | html2text | wc -w) unless self.url.nil?
  end

  def validate_url
    errors.add(:url, 'URL not valid') unless url =~ URI.regexp
  end
end
