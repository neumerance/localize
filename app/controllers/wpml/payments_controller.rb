class Wpml::PaymentsController < Wpml::BaseWpmlController
  include ProcessorLinks
  include CreateDeposit

  # set_website is implemented at Wpml::BaseWpmlController
  before_action { set_website(params[:website_id]) }
  before_action :authorize_client, except: [:paypal_complete]

  def new
    @header = 'Payment'
    @website.update_pending_translation_job_statuses
    @total_amount_without_tax = @website.total_amount
  end

  def create
    unless @user.can_pay?
      redirect_back(fallback_location: wpml_website_path(@website),
                    notice: 'Sorry, you do not have permission to pay.')
      return
    end

    return_address_after_payment = wpml_website_path(@website)
    missing_amount_without_tax = BigDecimal(params[:missing_amount_without_tax]).ceil_money
    payment_processor_code = params[:payment_processor].to_i

    if missing_amount_without_tax > 0
      invoice = create_invoice_for_wpml_website(@website.payable_cms_requests, missing_amount_without_tax, payment_processor_code)

      payment_url = case payment_processor_code
                    when EXTERNAL_ACCOUNT_PAYPAL
                      paypal_pay_invoice(invoice, @user, return_address_after_payment)
                    when EXTERNAL_ACCOUNT_2CHECKOUT
                      # The "amount" argument passed to prepare_2checkout_url
                      # should not include taxes. The tax amount is retrieved
                      # from the invoice.
                      prepare_2checkout_url(@user, invoice, missing_amount_without_tax)
                    else
                      raise 'Invalid payment processor.'
                    end

      # Redirect the user to the external payment processor
      redirect_to payment_url

      # When payment is complete, IF the client does not close the PayPal page
      # before the redirect (so this is *not* guaranteed to happen), PayPal
      # generates a GET request to FinanceController#paypal_complete. We are not
      # going to reimplement that action within this controller (for now). Even
      # though the action is not guaranteed to be triggered, we have to use it
      # because when the user gets redirected back to ICL, this action ensures his
      # payment is credited immediately (instead of waiting for the IPN, which
      # usually takes a few seconds but can take up to 48 hours).
    else
      # The client's ICL account balance is enough to cover all translation jobs
      # he is trying to pay for.
      @website.reserve_money_for_cms_requests(@website.payable_cms_requests)
      redirect_to wpml_website_path(@website)
    end
  end

  private

  def authorize_client
    # The #can_view? method is implemented in Client, Alias and Supporter models
    raise Error::NotAuthorizedError unless @user.can_view?(@website)
  end
end
