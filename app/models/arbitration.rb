class Arbitration < ApplicationRecord

  belongs_to :object, polymorphic: true

  has_many :reminders, as: :owner, dependent: :destroy
  has_many :messages, as: :owner, dependent: :destroy

  belongs_to :initiator, class_name: 'User', foreign_key: :initiator_id
  belongs_to :against, class_name: 'User', foreign_key: :against_id
  belongs_to :supporter

  has_many :arbitration_offers, dependent: :destroy
  has_one :accepted_offer, -> { where('arbitration_offers.status=?', OFFER_ACCEPTED) }, class_name: 'ArbitrationOffer'

  ARBITRATION_TYPE_TEXT = { MUTUAL_ARBITRATION_CANCEL_BID => 'Request to cancel bid, by mutual agreement',
                            SUPPORTER_ARBITRATION_CANCEL_BID => 'Request to cancel bid with assistance of support staff',
                            SUPPORTER_ARBITRATION_WORK_MUST_COMPLETE => 'Request to finalize work with assistance of support staff' }.freeze

  STATUS = { ARBITRATION_CREATED => N_('Created'),
             ARBITRATION_CLOSED => N_('Closed') }.freeze

  TIME_TO_RESPOND_TO_ARBITRATION = 3

  def other_party(user_id)
    if user_id == initiator_id
      against_id
    else
      initiator_id
    end
  end

end
