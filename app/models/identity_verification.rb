class IdentityVerification < ApplicationRecord
  belongs_to :normal_user, class_name: 'User', foreign_key: 'normal_user_id'
  belongs_to :verified_item, polymorphic: true
  has_one :support_ticket, as: :object

  validates_presence_of :normal_user, :verified_item

  STATUS_TEXT = { VERIFICATION_PENDING => N_('verification pending'),
                  VERIFICATION_DENIED => N_('verification denied'),
                  VERIFICATION_OK => N_('verification accepted') }.freeze

end
