module KeywordProjectMethods
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
  end

  def project_languages
    raise 'You must implement #project_languages to include KeywordProjectMethods!'
  end

  def unpaid_keywords
    keyword_projects.where(status: KeywordProject::PENDING_PAYMENT)
  end

  def purchased_keyword_packages
    project_languages.map(&:purchased_keyword_packages).flatten
  end

  def pending_keywords_cost
    unpaid_keywords.inject(0) { |a, b| a + b.keyword_package.price }
  end
end
