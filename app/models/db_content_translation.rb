class DbContentTranslation < ApplicationRecord
  belongs_to :owner, polymorphic: true
  belongs_to :language
end
