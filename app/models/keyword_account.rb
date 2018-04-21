class KeywordAccount < MoneyAccount
  belongs_to :keyword_project, foreign_key: :owner_id
end
