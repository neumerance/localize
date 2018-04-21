class RevisionSupportFile < ApplicationRecord
  belongs_to :revision
  belongs_to :support_file
end
