module MoneyTransactionsHelper
  def display_account(acc)
    content_tag(:span) do
      if acc.is_a? UserAccount
        unless acc.user.blank?
          concat content_tag(:span) {
            concat acc.user.fname; concat ' - '.html_safe; concat acc.user.lname; concat ' '.html_safe
          }
          concat link_to(acc.user.nickname, "/users/#{acc.user.id}")
        else
          concat 'Nothing. Possibly deleted.'.html_safe
        end
      elsif acc.is_a? KeywordAccount
        concat link_to 'Keyword project', "/keyword_projects/#{acc.keyword_project.id}"
      elsif acc.is_a? RootAccount
        concat 'ICanLocalize'.html_safe
      elsif acc.is_a? BidAccount
        concat link_to 'Bid escrow', "/projects/#{acc.bid.revision.project.id}/revisions/#{acc.bid.revision.id}/chats/#{acc.bid.chat.id}/bids/#{acc.bid.id}"
      elsif acc.is_a? ResourceLanguageAccount
        concat link_to 'Software escrow', "/text_resources/#{acc.resource_language.text_resource.id}/resource_chats/#{acc.resource_language.selected_chat.try(:id)}"
      elsif acc.nil?
        concat 'Nothing. Possibly deleted.'.html_safe
      end
    end
  end

  def transfer_type(acc)
    case acc.operation_code
    when TRANSFER_DEPOSIT_TO_BID_ESCROW
      'escrow to bid'
    when TRANSFER_PAYMENT_FROM_BID_ESCROW
      'payment from bid'
    when TRANSFER_REFUND_FROM_BID_ESCROW
      'refund from bid'
    when TRANSFER_DEPOSIT_FROM_EXTERNAL_ACCOUNT
      'deposit from external account'
    when TRANSFER_PAYMENT_TO_EXTERNAL_ACCOUNT
      'transfer to external account'
    when TRANSFER_REVERSAL_OF_PAYMENT_TO_EXTERNAL_ACCOUNT
      'cancel external transfer'
    when TRANSFER_FEE_FROM_TRANSLATOR
      'translator fee'
    when TRANSFER_PAYMENT_FOR_INSTANT_TRANSLATION
      'instant transaltion'
    when TRANSFER_PAYMENT_FOR_TA_RENTAL
      'ta rental'
    when TRANSFER_DEPOSIT_TO_RESOURCE_TRANSLATION # only translation
      'software payment'
    when TRANSFER_PAYMENT_FROM_RESOURCE_TRANSLATION # payment for the translation
      'software payment (with review?)'
    when TRANSFER_REFUND_FOR_RESOURCE_TRANSLATION # canceled translation
      'software project refund'
    when TRANSFER_PAYMENT_FROM_RESOURCE_REVIEW # payment for the review
      'payment resource review'
    when TRANSFER_DEPOSIT_TO_RESOURCE_TRANSLATION_WITH_REVIEW # translation with review
      'software translation with review'
    when TRANSFER_DEPOSIT_TO_RESOURCE_REVIEW # only review
      'software review'
    when TRANSFER_DEPOSIT_TO_PROJECT_REVIEW
      'project review'
    when TRANSFER_DEPOSIT_FOR_SERVICE_WORK # withdrawal to root account for service work
      'service work to ICL'
    when TRANSFER_GENERAL_REFUND
      'refund'
    when TRANSFER_PAYMENT_FROM_KEYWORD_LOCALIZATION
      'escrow for keywords'
    when TRANSFER_DEPOSIT_TO_RESOURCE_TRANSLATION_WITH_REVIEW_AND_KEYWORDS
      'payment translation + review + keywords'
    when TRANSFER_DEPOSIT_TO_RESOURCE_REVIEW_WITH_KEYWORDS
      'payment review + keywords'
    when TRANSFER_DEPOSIT_TO_RESOURCE_KEYWORDS
      'escrow to keywords from software'
    when TRANSFER_REUSE_KEYWORD
      'Reuse keyword'
    when TRANSFER_VOUCHER
      'Coupon Code'
    else
      'Transaction'
    end
  end

  def transfer_processor(transaction)
    if transaction.owner && transaction.owner.is_a?(Invoice)
      case transaction.owner.payment_processor
      when EXTERNAL_ACCOUNT_PAYPAL
        'Paypal'
      when EXTERNAL_ACCOUNT_CREDITCARD
        'Credit card'
      when EXTERNAL_ACCOUNT_CHECK
        'Test deposit'
      when EXTERNAL_ACCOUNT_BANK_TRANSFER
        'Bank transfer'
      when EXTERNAL_ACCOUNT_GOOGLE_CHECKOUT
        'Google checkout'
      when EXTERNAL_ACCOUNT_2CHECKOUT
        '2checkout'
      else
        'Invalid processor'
      end
    else
      'Not available'
    end
  end
end
