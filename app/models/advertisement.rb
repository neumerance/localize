class Advertisement < ApplicationRecord
  has_many :leads

  def get_title(lead)
    replace_fields(title, lead)
  end

  def get_body(lead)
    replace_fields(body, lead)
  end

  private

  def replace_fields(txt, lead)
    res = txt.gsub('$GREETING', greeting_txt(lead))
    res = res.gsub('$WHAT_THEY_DO', lead.what_they_do)
    res = res.gsub('$URL', strip_http(lead.url))
    res
  end

  def greeting_txt(lead)
    if !lead.contact_fname.blank?
      "Dear #{lead.contact_fname.capitalize}"
    else
      'Hello'
    end
  end

  def strip_http(url)
    res = url.downcase
    if /^http:\/\//.match(url)
      return res[7..-1]
    elsif /^https:\/\//.match(url)
      return res[8..-1]
    else
      return res
    end
  end

end
