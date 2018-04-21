class Message < ApplicationRecord
  # acts_as_ferret :fields => [:body], :index_dir => "#{FERRET_INDEX_DIR}/message"

  belongs_to :user
  belongs_to :owner, polymorphic: true
  has_many :attachments, dependent: :destroy
  has_many :message_deliveries, dependent: :destroy
  has_many :users, through: :message_deliveries

  include ParentWithSiblings

  validates :body, length: { maximum: COMMON_NOTE }

  before_create :encode_emojis

  def encode_emojis
    return if body.nil?
    self.body = Rumoji.encode body
  end

  def body_with_emojis
    return '' if body.nil?
    Rumoji.decode body
  end

  # return list of siblings
  def siblings
    []
  end

  def can_delete_me
    true
  end

  def to_json
    {
      data: {
        id: self.id,
        body: self.body
      }
    }
  end

end
