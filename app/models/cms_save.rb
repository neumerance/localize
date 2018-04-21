class CmsSave < ApplicationRecord

  belongs_to :cms_request
  belongs_to :xliff
  belongs_to :client
  belongs_to :translator
  belongs_to :source_language, class_name: Language, foreign_key: :source_language_id
  belongs_to :target_language, class_name: Language, foreign_key: :target_language_id

end
