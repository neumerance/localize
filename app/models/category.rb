class Category < ApplicationRecord
  has_many :translators, through: :translator_categories
  has_many :revisions, through: :revision_categories

  def nname
    _(name)
  end

  def self.list
    [[_('--- Please choose --'), 0]] + (Category.all.collect { |c| [c.nname, c.id] }).sort
  end
end
