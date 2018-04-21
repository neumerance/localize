class Language < ApplicationRecord
  attr_accessor :skip_language_pairs_creation

  validates_uniqueness_of :name
  has_many :revision_languages, dependent: :destroy
  has_many :statistics, dependent: :destroy
  has_many :translator_languages, dependent: :destroy
  has_many :search_urls, dependent: :destroy
  has_many :keywords, dependent: :destroy
  has_one :google_language

  has_many :available_language_froms, class_name: 'AvailableLanguage', foreign_key: :from_language_id
  has_many :available_language_tos, class_name: 'AvailableLanguage', foreign_key: :to_language_id

  has_many :cms_requests
  has_many :cms_target_languages
  has_many :language_pair_fixed_prices, dependent: :destroy

  ALL_LANGUAGES = Hash[all.map { |l| [l.id, l] }]

  after_create :create_language_pairs_and_calculate_prices, unless:
    :skip_language_pairs_creation

  def is_asian?
    Language.asian_language_ids.include? id
  end

  def self.[](name_or_iso)
    k = name_or_iso.size == 2 ? :iso : :name
    Language.find_by(k => name_or_iso.to_s)
  end

  def list
    Hash[all.map { |l| [l.id, l.name] }]
  end

  def self.list_major_first(exclude_list = [])
    conds = []
    conds << "(id NOT IN (#{exclude_list.join(',')}))" unless exclude_list.empty?
    res = [['---', 0]]
    res += Language.where((conds + ['(major=1)']).join(' AND ')).order('name ASC').collect { |lang| [lang.name, lang.id] }
    res << ['---', 0]
    res += Language.where((conds + ['(major=0)']).join(' AND ')).order('name ASC').collect { |lang| [lang.name, lang.id] }
    res
  end

  def self.have_translators(exclude_list = [], include_unqualified = false, _available_for_cms = false)

    cond = if include_unqualified
             'EXISTS(SELECT al.id FROM available_languages al WHERE (al.from_language_id=languages.id))'
           else
             'EXISTS(SELECT al.id FROM available_languages al WHERE ((al.from_language_id=languages.id) AND (al.qualified IN (1,2))))'
           end

    find_by_conds([cond], exclude_list)
  end

  def self.find_by_conds(initial_conds, exclude_list = [])
    conds = initial_conds
    conds << "(id NOT IN (#{exclude_list.join(',')}))" unless exclude_list.empty?
    major_languages = Language.where((conds + ['(languages.major=1)']).join(' AND ')).order('name ASC').collect { |lang| [lang.name, lang.id] }
    minor_languages = Language.where((conds + ['(languages.major=0)']).join(' AND ')).order('name ASC').collect { |lang| [lang.name, lang.id] }

    if !major_languages.empty? && !minor_languages.empty?
      return [['---', 0]] + major_languages + [['---', 0]] + minor_languages
    else
      return major_languages + minor_languages
    end
  end

  def self.to_languages_with_translators(from_language_id, include_unqualified)
    have_translator_conds = []

    additional_cond = if include_unqualified
                        ''
                      else
                        'AND (al.qualified IN (1,2))'
                      end
    have_translator_conds << "EXISTS(SELECT al.id FROM available_languages al WHERE ((al.to_language_id=l.id) AND (al.from_language_id=#{from_language_id}) #{additional_cond}))"
    # have_translator_conds << "l.id != #{from_language_id}"

    Language.find_by_sql("SELECT DISTINCT l.* FROM languages l WHERE #{have_translator_conds.join(' AND ')}")
  end

  def self.asian_language_ids
    unless @asian_language_ids_cache
      @asian_language_ids_cache =
        Language.where(
          'name IN (?)',
          ['Japanese',
           'Korean',
           'Chinese (Simplified)',
           'Chinese (Traditional)',
           'Mongolian',
           'Nepali',
           'Hindi',
           'Panjabi',
           'Tamil',
           'Thai']
        ).pluck(:id)
    end
    @asian_language_ids_cache
  end

  def <=>(a)
    name <=> a.name
  end

  def nname
    _(name)
  end

  def self.cached_language(id)
    ALL_LANGUAGES[id]
  end

  def self.detect_language(lang_iso_or_name)
    lang = Language.find_by name: lang_iso_or_name
    lang = Language.find_by iso: lang_iso_or_name unless lang
    lang
  end

  # Exceptions
  class NotFound < JSONError
    def initialize(language)
      @code = LANGUAGE_NOT_FOUND
      @message = "Can't find language #{language}"
    end
  end

  private

  def create_language_pairs_and_calculate_prices
    LanguagePairFixedPrice.create_all_pairs_for_new_language(self)
  end
end
