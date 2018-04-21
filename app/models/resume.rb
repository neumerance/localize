class Resume < Document

  if Rails.env.production?
    acts_as_ferret(fields: [:body],
                   index_dir: "#{FERRET_INDEX_DIR}/document",
                   remote: true)
  end

  def markup(locale_language)
    ret = i18n_txt(locale_language)
    return ret if ret.nil?
    ret.gsub("\n", '<br />')
  end

  def save
    self.chgtime = Time.now
    super
  end

  def save!
    self.chgtime = Time.now
    super
  end

end
