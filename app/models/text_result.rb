class TextResult < ApplicationRecord
  belongs_to :owner, polymorphic: true
end