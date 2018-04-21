class Lock < ApplicationRecord
  belongs_to :object, polymorphic: true
end
