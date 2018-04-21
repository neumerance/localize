class PrivateTranslator < ApplicationRecord
  belongs_to :client, touch: true
  belongs_to :translator, touch: true

  STATUS_TEXT = { PRIVATE_TRANSLATOR_PENDING => N_('Invitation sent'),
                  PRIVATE_TRANSLATOR_ACCEPTED => N_('Invitation accepted'),
                  PRIVATE_TRANSLATOR_DENIED => N_('Invitation declined') }.freeze
end
