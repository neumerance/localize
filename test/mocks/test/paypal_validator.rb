require Rails.root.join('lib/paypal_validator.rb')

class PaypalValidator

  def pdt_post_to_paypal(postData)
    call_args = {}
    postData.split('&').each do |arg|
      w = arg.split('=')
      call_args[URI.decode(w[0])] = URI.decode(w[1])
    end
    call_args.each { |k, v| @logger.info "---- MOCK DECODED - #{k}: #{v}" }

    res = []

    tx = call_args['tx']
    if tx.blank?
      res << 'FAILED' << 'No TX'
    else
      # look for the transaction in the mock database
      transaction = PaypalMockReply.where('txn_id=?', tx).first
      if transaction
        res << 'SUCCESS'
        transaction.attributes.each { |k, v| res << "#{k}=#{v}" }
      else
        res << 'FAILED' << "Cannot_locate_TX-#{tx}"
      end
    end
    res.join("\n")
  end

  def validate_ipn(_raw_post)
    true
  end

  # i need to comment this out because this will fail all Rejected paypal request test
  # see integration/payment_test.rb:561
  # def validate_pdt(txn)
  #   true
  # end
end
