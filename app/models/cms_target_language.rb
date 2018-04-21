#  .word_count
# 				Is the same number that appear on revision, this is used for billing
#
# Statuses:
#   CMS_TARGET_LANGUAGE_CREATED 	 = 0
#   CMS_TARGET_LANGUAGE_ASSIGNED 	 = 1
#     Translator clicked the "Start Translation" button,
#     CmsRequestsController#assign_to_me was called, the PendingMoneyTransaction
#     was deleted and money was moved from the hold_sum to an escrow account.
#   CMS_TARGET_LANGUAGE_TRANSLATED = 2
#   CMS_TARGET_LANGUAGE_DONE 			 = 3
class CmsTargetLanguage < ApplicationRecord
  belongs_to :cms_request, touch: true
  belongs_to :language
  belongs_to :translator, touch: true
  has_many :cms_downloads, foreign_key: :owner_id, dependent: :destroy
  belongs_to :money_account

  before_save :audit_word_count_changes, if: -> { attribute_changed?(:word_count) && self.persisted? }

  STATUS_TEXT = {
    CMS_TARGET_LANGUAGE_CREATED => N_('Waiting for translator'),
    CMS_TARGET_LANGUAGE_ASSIGNED => N_('Being translated'),
    CMS_TARGET_LANGUAGE_TRANSLATED => N_('Translation received'),
    CMS_TARGET_LANGUAGE_DONE => N_('Translation completed'),
    CMS_TARGET_LANGUAGE_AWAITING_PAYMENT => N_('Awaiting payment')
  }.freeze

  def payment
    required_balance, bid_amounts, rental_amounts, payments_to_translator = cms_request.calculate_required_balance([self], nil)
    required_balance
  end

  private

  def audit_word_count_changes
    previous, current = attribute_change(:word_count)

    # Keep in mind that both 'previous' and 'current' can be nil
    if previous && previous != 0 && current && current > previous
      # Don't allow the update
      self.word_count = previous
      Rails.logger.info 'An attempt to update the word_count attribute of ' \
                        "cms_target_language #{self.id} from '#{previous}' to " \
                        "'#{current}' was forbidden.\n" \
                        "The call stack that attempted the update was:\n#{Logging.format_callstack(self, caller)}."
    else
      # Allow the update
      Rails.logger.info "cms_target_language #{self.id} had its word_count attribute " \
                        "updated from '#{previous}' to '#{current}'.\n" \
                        "The call stack that resulted in the update was:\n#{Logging.format_callstack(self, caller)}."
    end
  end
end
