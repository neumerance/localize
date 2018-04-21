class TranslatorCategory < ApplicationRecord
  belongs_to :translator, touch: true
  belongs_to :category
end
