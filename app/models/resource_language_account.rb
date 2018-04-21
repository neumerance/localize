class ResourceLanguageAccount < MoneyAccount
  belongs_to :resource_language, foreign_key: :owner_id, class_name: 'ResourceLanguage'
end
