#   status:
#     WORDS_STATUS_DONE_CODE = 0
#     WORDS_STATUS_NEW_CODE = 1
#     WORDS_STATUS_MODIFIED_CODE = 2
class Statistic < ApplicationRecord
  belongs_to :version
  belongs_to :language
  belongs_to :dest_language, class_name: 'Language', foreign_key: 'dest_language_id'
end
