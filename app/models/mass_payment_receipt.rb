class MassPaymentReceipt < ApplicationRecord

  TRANSFER_STATUS_TEXT = { TXN_CREATED => N_('Sent to PayPal, pending completion'),
                           TXN_COMPLETED => N_('Complete'),
                           TXN_CANCELED_REVERSAL => N_('Canceled'),
                           TXN_DENIED => N_('Denied'),
                           TXN_EXPIRED => N_('Expired'),
                           TXN_FAILED => N_('Failed'),
                           TXN_PENDING => N_('Pending'),
                           TXN_PROCESSED => N_('Processing'),
                           TXN_REFUNDED => N_('Refunded'),
                           TXN_REVERSED => N_('Reversed'),
                           TXN_VOIDED => N_('Voided'),
                           TXN_UNCLAIMED => N_('Unclaimed') }.freeze

  belongs_to :withdrawal
  has_one :money_transaction, as: :owner
end
