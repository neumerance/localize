module KeywordProjectLanguage

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def keyword_language_associations
      has_many :keyword_projects, as: :owner
      has_many :purchased_keyword_packages, through: :keyword_projects
    end
  end

  def project
    raise 'You must implement #project for keyword project languages!'
  end

  def remaining_keywords
    purchased_keyword_packages.find_all { |pkp| pkp.keyword_project.status == KeywordProject::PAID }.inject(0) { |a, b| a + b.remaining_keywords }
  end

  def pending_keywords?
    purchased_keyword_packages.find_all { |pkp| pkp.keywords.find_all(&:pending?).any? }.find_all { |pkp| pkp.keyword_project.status == KeywordProject::PAID }.any?
  end

  def pending_keyword_projects
    keyword_projects.find_all(&:pending?)
  end

  def unpaid_keywords
    keyword_projects.where(status: KeywordProject::PENDING_PAYMENT)
  end

  def subtract_remaining_keywords(word_count)
    raise "don't have that much keywords to substract" if word_count > remaining_keywords
    result = {}

    packages = purchased_keyword_packages.find_all { |pkp| pkp.remaining_keywords > 0 }
    packages.each do |package|
      remaining_words = package.remaining_keywords
      to_remove_from_this_package = remaining_words > word_count ? word_count : remaining_words
      package.update_attribute :remaining_keywords, remaining_words - to_remove_from_this_package
      word_count -= to_remove_from_this_package
      result[package.keyword_project] = package.keyword_project.translator_payment_for(to_remove_from_this_package)
      break if word_count == 0
    end

    result
  end
end
