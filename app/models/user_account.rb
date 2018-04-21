class UserAccount < MoneyAccount
  belongs_to :normal_user, foreign_key: :owner_id, class_name: 'User'
  alias user normal_user
end
