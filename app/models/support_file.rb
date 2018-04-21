class SupportFile < ZippedFile
  has_many :revisions, through: :revision_support_files
  has_many :revision_support_files, dependent: :destroy
  belongs_to :project, foreign_key: :owner_id

  include ParentWithSiblings

  # return list of siblings
  def siblings
    []
  end

  def can_delete_me
    true
  end

end
