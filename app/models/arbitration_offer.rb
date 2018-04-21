class ArbitrationOffer < ApplicationRecord
  belongs_to :arbitration
  belongs_to :user

  def percentage=(val)
    self.amount = arbitraion.bid.amount * val / 100.0
  end

  def percentage
    100.0 * amount / arbitraion.bid.amount
  end

end
