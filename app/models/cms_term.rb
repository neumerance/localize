class CmsTerm < ApplicationRecord
  belongs_to :website
  belongs_to :language
  belongs_to :parent, class_name: 'CmsTerm', foreign_key: :parent_id
  has_many :children, class_name: 'CmsTerm', foreign_key: :parent_id, dependent: :destroy
  has_many :cms_term_translations, dependent: :destroy

  def children_by_kind(kind)
    return children.where(kind: kind) if kind
    children
  end
end
