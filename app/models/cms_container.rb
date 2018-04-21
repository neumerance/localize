class CmsContainer < ZippedFile
  belongs_to :website, foreign_key: :owner_id
  belongs_to :user, foreign_key: :by_user_id
end
