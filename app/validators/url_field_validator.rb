class UrlFieldValidator < ActiveModel::EachValidator
  require 'uri'
  def validate_each(record, field, value)
    check_a_url(record, field, value) unless value.blank? || value.nil?
  end

  private

  def check_a_url(record, field, value)

    uri = URI.parse(value)
    record.errors[field] << _('must begin with HTTP:// or HTTPS://') unless [URI::HTTP, URI::HTTPS].include? uri.class
    # removing this due to icldev-876
    # record.errors[field] << _('Invalid URL format') unless (value =~ /^(http|https):\/\/[a-z0-9]+([\-\.]{1}[a-z0-9]+)*\.[a-z]{2,5}(:[0-9]{1,5})?(\/.*)?$/ix) == 0
  rescue URI::InvalidURIError
    record.errors[field] << _('invalid web address')

  end
end
