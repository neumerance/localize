class RevisionCategory < ApplicationRecord
  belongs_to :revision
  belongs_to :category
end
