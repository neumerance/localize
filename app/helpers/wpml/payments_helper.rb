module Wpml::PaymentsHelper
  def website_payment(website, current_user, total_amount_without_tax)
    client = website.client
    client_money_account = client.find_or_create_account(DEFAULT_CURRENCY_ID)

    # Round up
    total_amount_without_tax = total_amount_without_tax.ceil_money
    missing_amount_without_tax = total_amount_without_tax - client_money_account.balance
    # Can't be negative
    missing_amount_without_tax = 0 if missing_amount_without_tax < 0
    tax_amount = client.has_to_pay_taxes? ? client.calculate_tax(missing_amount_without_tax) : 0
    missing_amount_with_tax = missing_amount_without_tax + tax_amount

    # Most of the following code was taken from websites_helper.rb
    # TODO: Refactor this. Implement as a partial instead of a helper
    content_tag(:div, id: 'missing_funds') do
      concat content_tag(:h3, 'Missing Funding')
      concat form_tag(wpml_website_payments_path(website), autocomplete: 'off') {
        concat render partial: 'shared/vat_request' if current_user.can_pay?
        concat content_tag(:div, id: 'total_box') {
          concat content_tag(:table, cellspacing: 0, cellpadding: 3, class: 'stats', width: '100%') {
            concat content_tag(:tr, class: 'headerrow') {
              %w(Description Cost).each { |th| concat content_tag(:th, th) }
            }

            # Description of what the client is paying for (total amount
            # without tax)
            concat content_tag(:tr, class: 'item') {
              concat content_tag(:td) {
                concat ''.html_safe; concat ' Required amount for translation jobs'
              }
              concat content_tag(:td) {
                concat content_tag(:span, total_amount_without_tax, class: 'amount')
                concat ' USD'.html_safe
                concat hidden_field_tag("transaction_code#{website.id}", TRANSFER_DEPOSIT_FROM_EXTERNAL_ACCOUNT)
              }
            }

            # Current balance of client account
            concat content_tag(:tr, class: 'current_in_account') {
              concat content_tag(:td, 'Currently in your ICanLocalize account')
              concat content_tag(:td) {
                concat content_tag(:span, sprintf('%.2f', client_money_account.balance), class: 'amount')
                concat ' USD'.html_safe
              }
            }

            if missing_amount_without_tax > 0
              # Missing amount (total - client account balance) withOUT tax
              concat content_tag(:tr, class: 'subtotal') {
                concat content_tag(:th, 'Subtotal')
                concat content_tag(:th) {
                  concat content_tag(:b) {
                    concat content_tag(:span, missing_amount_without_tax, class: 'amount')
                    concat ' USD'.html_safe
                  }
                }
              }

              # TAX amount
              hide_row = client.has_to_pay_taxes? ? '' : 'display:none'
              concat content_tag(:tr, class: 'tax_details', style: hide_row) {
                concat content_tag(:td) {
                  concat 'VAT Tax in '.html_safe
                  concat content_tag(:span, client.country.try(:name), class: 'country_name')
                  concat ' ('.html_safe
                  concat content_tag(:span, client.tax_rate.to_i, class: 'tax_rate')
                  concat ') '.html_safe
                }
                concat content_tag(:td) {
                  concat content_tag(:span, tax_amount, class: 'amount')
                  concat ' USD'.html_safe
                }
              }

              # Missing amount with tax (value that the client will pay)
              concat content_tag(:tr) {
                concat content_tag(:th, content_tag(:b, 'Payment amount'))
                concat content_tag(:th) {
                  concat content_tag(:b, missing_amount_with_tax, id: 'total_cost')
                  concat content_tag(:b, ' USD')
                }
              }
            end # missing_amount_without_tax > 0
          }
          concat '<br />'.html_safe
        }

        # The amount *without* tax must be sent. Taxes are recalculated
        # when the invoice is generated.
        concat hidden_field_tag(:missing_amount_without_tax, missing_amount_without_tax)

        if missing_amount_without_tax > 0
          # Supporters can't pay using an external payment processor.
          if current_user.class.in?([Client, Alias]) && current_user.can_pay?
            # The client's ICL account balance is *not* enough to cover all translation jobs
            concat radio_button_tag(:payment_processor, EXTERNAL_ACCOUNT_PAYPAL, true, class: 'm-r-5')
            concat content_tag(:label, _('Pay with PayPal'))
            concat '<br />'.html_safe
            concat image_tag('paypal_payments.png', style: 'margin: 5px', width: 242, height: 31, alt: 'PayPal payment options')
            concat '<br />'.html_safe
            concat content_tag(:p, 'You don\'t need to have a PayPal account. PayPal allows you to pay with a credit card as well.<BR>' \
                                   'Payments with a credit card or from your PayPal balance, complete immediately. E-Check payments take' \
                                   '3-4 days to complete.'.html_safe, class: 'comment')
            concat '<br />'.html_safe

            if CO_ENABLED
              concat radio_button_tag(:payment_processor, EXTERNAL_ACCOUNT_2CHECKOUT, false, class: 'm-r-5')
              concat content_tag(:label, _('Pay with 2Checkout'))
              concat '<br />'.html_safe
              concat image_tag 'https://www.2checkout.com/upload/images/paymentlogoshorizontal.png', alt: 'Google Checkout'
              concat '<br />'.html_safe
              concat content_tag(:p, 'Pay with most credit cards. Payments take up to several hours to complete processing.', class: 'comment')
            end

            concat submit_tag('Pay', style: 'padding: 0.5em 1em;', id: 'pay', class: 'button_X', data: { disable_with: 'Redirecting to payment processor...' })
          else
            concat content_tag(:div, 'This payment requires using an external payment processor such as PayPal. You are not authorized to do that.', class: 'red_panel', style: 'margin-bottom: 20px;')
          end
        elsif total_amount_without_tax > 0
          button_text = 'Pay with my ICanLocalize account balance'

          # Supporters can pay using the client's ICL account balance
          if current_user.has_supporter_privileges?
            message = "The client has enough balance in his ICanLocalize
              account to pay for all translation jobs. You can click the
              button below and pay with the client's balance. Before
              doing that, make sure that the client has chosen which language
              pairs should have review enabled or disabled in the
              #{link_to 'Pending Translation Jobs page', wpml_website_translation_jobs_path(@website.id)}.
              After paying, reviews can no longer be enabled or disabled for
              those translation jobs."
            concat content_tag(:div, message.html_safe, class: 'red_panel', style: 'margin-bottom: 20px;')

            button_text = 'Pay with the client\'s ICanLocalize account balance'
          end

          # supporter.can_pay? returns true
          if current_user.can_pay?
            # The client's ICL account balance *is* enough to cover all
            # translation jobs he is trying to pay for.
            concat submit_tag(button_text,
                              style: 'padding: 0.5em 1em;',
                              id: 'pay-with-icl-balance',
                              data: { disable_with: 'Processing payment...' })
          else
            concat content_tag(:div, 'You are not authorized to make payments for this website.', class: 'red_panel', style: 'margin-bottom: 20px;')
          end
        else
          concat content_tag(:div, 'There is nothing to pay for.', class: 'red_panel', style: 'margin-bottom: 20px;')
        end
      }
    end
  end
end
