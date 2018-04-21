module AdminFinanceHelper
  def account_description(account)
    if (account.class == UserAccount) && account.normal_user
      link_to("%s's account" % account.normal_user.try(:full_name), controller: :finance, action: :account_history, id: account.id)
    elsif account.class == BidAccount
      bid = account.bid
      link_to('bid', controller: :bids, action: :show, id: bid.id, chat_id: bid.chat_id, revision_id: bid.chat.revision_id, project_id: bid.chat.revision.project_id)
    elsif account.class == ExternalAccount
      "#{ExternalAccount::NAME[account.external_account_type]} account: #{account.identifier}"
    else
      'some account'
    end
  end

  def money_transaction_details(_account_line, money_transaction)
    "From #{account_description(money_transaction.source_account)} to #{account_description(money_transaction.target_account)}"
  end

  def amount_with_sign(money_transaction)
    if money_transaction.source_account.class == ExternalAccount
      money_transaction.amount
    else
      -money_transaction.amount
    end
  end

  def display_paypal_transactions(all_events, user)
    content_tag(:tbody) do
      keys = all_events.keys().sort
      keys.each do |key|
        entry = all_events[key]
        if entry.class == Invoice
          date = entry.modify_time
          description = content_tag(:span) {
            concat  'Invoice '.html_safe
            concat content_tag(:span, entry.id); concat ' :<br />'.html_safe
            concat content_tag(:ul, style: 'padding: 0') {
              concat content_tag(:li, content_tag(:span, entry.description(user)), style: 'list-style-type: none')
            }
          }
          net_amount = entry.net_amount
          gross_amount = entry.gross_amount
          col = '#E0FFE0'
        else
          total = 0
          fees = 0
          descriptions = []
          entry.mass_payment_receipts.each do |mass_payment_receipt|
            money_transaction = mass_payment_receipt.money_transaction
            total += money_transaction.amount if money_transaction.present?
            fees += mass_payment_receipt.fee
            sa = money_transaction.source_account if money_transaction.present?
            name = sa.present? ? "#{sa.normal_user.try(:full_name)} #{sa.normal_user.try(:type)}" : 'Unknown'
            descriptions << "withdrawal from user account: #{name}"
          end
          date = entry.submit_time
          description = content_tag(:span) {
            concat  'MassPay '.html_safe
            concat content_tag(:span, entry.id); concat ' :<br />'.html_safe
            concat content_tag(:ul, style: 'padding: 0') {
              descriptions.each do |desc|
                concat content_tag(:li, desc, style: 'list-style-type: none')
              end
            }
          }
          net_amount = -total
          gross_amount = -(total + fees)
          col = '#FFE0E0'
        end
        concat content_tag(:tr) {
          concat content_tag(:td, disp_date(date), style: "background-color: #{col}")
          concat content_tag(:td, description, style: "background-color: #{col}")
          concat content_tag(:td, net_amount, style: "background-color: #{col}")
          concat content_tag(:td, gross_amount, style: "background-color: #{col}")
        }
      end
    end
  end

end
