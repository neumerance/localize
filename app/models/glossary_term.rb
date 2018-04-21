class GlossaryTerm < ApplicationRecord
  belongs_to :client
  belongs_to :language
  has_many :glossary_translations, dependent: :destroy

  validates :txt, :language_id, presence: true
  validates :txt, length: { maximum: COMMON_FIELD }
  validates :description, length: { maximum: COMMON_FIELD }

  COMMON_WORDS = ['the', 'of', 'and', 'a', 'to', 'in', 'is', 'you', 'that', 'it', 'he', 'was', 'for', 'on', 'are', 'as', 'with', 'his', 'they', 'i', 'at', 'be',
                  'this', 'have', 'from', 'or', 'one', 'had', 'by', 'word', 'but', 'not', 'what', 'all', 'were', 'we', 'when', 'your', 'can', 'said', 'there', 'use', 'an', 'each',
                  'which', 'she', 'do', 'how', 'their', 'if', 'will', 'up', 'other', 'about', 'out', 'many', 'then', 'them', 'these', 'so', 'some', 'her', 'would', 'make', 'like', 'him',
                  'into', 'time', 'has', 'look', 'two', 'more', 'write', 'go', 'see', 'number', 'no', 'way', 'could', 'people', 'my', 'than', 'first', 'water', 'been', 'call', 'who',
                  'oil', 'its', 'now', 'find', 'long', 'down', 'day', 'did', 'get', 'come', 'made', 'may', 'part', 'over', 'new', 'sound', 'take', 'only', 'little', 'work', 'know',
                  'place', 'year', 'live', 'me', 'back', 'give', 'most', 'very', 'after', 'thing', 'our', 'just', 'name', 'good', 'sentence', 'man', 'think', 'say', 'great', 'where',
                  'help', 'through', 'much', 'before', 'line', 'right', 'too', 'mean', 'old', 'any', 'same', 'tell', 'boy', 'follow', 'came', 'want', 'show', 'also', 'around', 'form',
                  'three', 'small', 'set', 'put', 'end', 'does', 'another', 'well', 'large', 'must', 'big', 'even', 'such', 'because', 'turn', 'here', 'why', 'ask', 'went', 'men',
                  'read', 'need', 'land', 'different', 'home', 'us', 'move', 'try', 'kind', 'hand', 'picture', 'again', 'change', 'off', 'play', 'spell', 'air', 'away', 'animal',
                  'house', 'point', 'page', 'letter', 'mother', 'answer', 'found', 'study', 'still', 'learn', 'should', 'America', 'world', 'high', 'every', 'near', 'add', 'food',
                  'between', 'own', 'below', 'country', 'plant', 'last', 'school', 'father', 'keep', 'tree', 'never', 'start', 'city', 'earth', 'eye', 'light', 'thought', 'head',
                  'under', 'story', 'saw', 'left', "don't", 'few', 'while', 'along', 'might', 'close', 'something', 'seem', 'next', 'hard', 'open', 'example', 'begin', 'life',
                  'always', 'those', 'both', 'paper', 'together', 'got', 'group', 'often', 'run', 'important', 'until', 'children', 'side', 'feet', 'car', 'mile', 'night', 'walk',
                  'white', 'sea', 'began', 'grow', 'took', 'river', 'four', 'carry', 'state', 'once', 'book', 'hear', 'stop', 'without', 'second', 'later', 'miss', 'idea', 'enough',
                  'eat', 'face', 'watch', 'far', 'indian', 'really', 'almost', 'let', 'above', 'girl', 'sometimes', 'mountain', 'cut', 'young', 'talk', 'soon', 'list', 'song', 'being',
                  'leave', 'family', "it's", 's'].freeze

  PUNCTUATION = ['.', ',', '"', "'", ':', ';', '(', ')', '[', ']', '{', '}'].freeze

  def self.split_with_punctuation(txt)
    t = txt
    PUNCTUATION.each { |p| t = t.gsub(p, ' ') }
    t.split
  end

  def self.find_frequent_words(txt)
    t = txt
    PUNCTUATION.each { |p| t = t.gsub(p, ' ') }
    words = t.split
    hist = {}
    count = 0
    words.each do |w|
      wl = w.downcase
      next unless (wl.length > 2) && !COMMON_WORDS.include?(wl)
      if !hist.key?(wl)
        hist[wl] = 1
      else
        hist[wl] += 1
      end
      count += 1
    end

    to_sort = []
    hist.each { |k, v| to_sort << [v, k] }

    res = []
    counted = 0

    stop_count = (count / 7).to_i

    to_sort.sort.reverse.each do |item|
      res << item[1]
      counted += item[0]
      break if counted >= stop_count
    end

    res

  end

  def self.webta_create(params, cms_request)
    return ApiError.new(400, 'Glossary term can not be blank', 'INVALID DATA').error if params[:term].blank?
    return ApiError.new(400, 'Description can not be blank', 'INVALID DATA').error if params[:description].blank?
    return ApiError.new(400, 'Translated text can not be blank', 'INVALID DATA').error if params[:translated_text].blank?
    target_language = cms_request.cms_target_language.language

    glossary_params = {
      client_id: cms_request.website.client_id,
      txt: params[:term],
      description: params[:description],
      language_id: cms_request.language_id
    }
    glossary = GlossaryTerm.new(glossary_params)
    glossary.glossary_translations.new(txt: params[:translated_text], language_id: target_language.id)
    glossary.save!

    glossary.to_json(target_language)
  rescue => e
    return ApiError.new(400, e.message, 'UNEXPECTED ERROR').error
  end

  def self.webta_update(params, cms_request, user)
    glossary_term = GlossaryTerm.find_by_id(params[:id])
    return ApiError.new(404, 'Glossary term not found', 'NOT FOUND').error unless glossary_term.present?
    return ApiError.new(403, 'Can not update this term', 'NOT ALLOWED').error unless glossary_term.client_id == cms_request.website.client_id
    glossary_term.update_attributes!(description: params[:description]) if params[:description].present?
    if params[:translation].present? && params[:target_language_id]
      glossary_translation = glossary_term.glossary_translations.where(language_id: params[:target_language_id]).last
      if glossary_translation.present?
        glossary_translation.update_attributes!(txt: params[:translation], last_editor_id: user.id)
      else
        GlossaryTranslation.new(
          glossary_term_id: glossary_term.id,
          language_id: params[:target_language_id],
          txt: params[:translation],
          creator_id: user.id,
          last_editor_id: user.id
        ).save!
      end
    end
    return { code: 200, status: 'OK', message: 'Glossary updated' }
  rescue => e
    return ApiError.new(400, e.message, 'UNEXPECTED ERROR').error
  end

  def to_json(target_language)
    {
      id: self.id,
      term: self.txt,
      description: self.description,
      original_language: self.language.name,
      translated_text: self.glossary_translations.where(language: target_language).first.txt,
      translation_language: target_language.name
    }
  end

end
