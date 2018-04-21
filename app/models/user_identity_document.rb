class UserIdentityDocument < UserDocument
  belongs_to :normal_user, foreign_key: :owner_id
  has_one :identity_verification, as: :verified_item, dependent: :destroy
end
