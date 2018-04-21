class Tag < ApplicationRecord
  belongs_to :object, polymorphic: true
end
