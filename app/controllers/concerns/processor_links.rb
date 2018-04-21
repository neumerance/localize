module ProcessorLinks
  def make_uri(domain, params)
    encoded_params = []
    params.each { |k, v| encoded_params << "#{k}=#{URI.escape(v.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))}" }
    url = "#{domain}?#{encoded_params.join('&')}"
    Rails.logger.info "ProcessorLinks URI: #{url}"
    url
  end
  private :make_uri

  # used for bid projects
  def paypal_pay_invoices(invoices, user, return_addr)
    params = {
      'cmd' => '_xclick',
      'business' => Figaro.env.PAYPAL_BUSINESS_EMAIL,
      'item_name' => invoices.inject('') { |a, b| a + b.description(user).gsub(/<.*?>/, '') },
      'amount' => '%.2f' % invoices.inject(0) { |a, b| a + b.gross_amount },
      'tax' => '%.2f' % invoices.inject(0) { |a, b| a + b.tax_amount },
      'tax_rate' => '%.2f' % invoices.first.tax_rate,
      'currency_code' => invoices.first.currency.name,
      'invoice' => invoices.map(&:id).join(','),
      'no_shipping' => 1,
      'no_note' => 1,
      'bn' => 'PP-BuyNowBF',
      'charset' => 'UTF-8',
      'cancel_return' => return_addr,
      'notify_url' => url_for(controller: '/finance', action: :paypal_ipn),
      'return' => url_for(controller: '/finance', action: :paypal_complete),
      'rm' => 1,
      'page_style' => 'icanlocalize'
    }
    make_uri(Figaro.env.PAYPAL_URLS, params)
  end

  # Used by multiple project types, such as website translation, software
  # translation and instant translation.
  def paypal_pay_invoice(invoice, user, return_addr)
    params = {
      'cmd' => '_xclick',
      'business' => Figaro.env.PAYPAL_BUSINESS_EMAIL,
      'item_name' => invoice.description(user),
      'amount' => '%.2f' % invoice.gross_amount,
      'tax' => '%.2f' % invoice.tax_amount,
      'tax_rate' => '%.2f' % invoice.tax_rate,
      'currency_code' => invoice.currency.name,
      'invoice' => invoice.id,
      'no_shipping' => 1,
      'no_note' => 1,
      'bn' => 'PP-BuyNowBF',
      'charset' => 'UTF-8',
      'cancel_return' => return_addr,
      'notify_url' => url_for(controller: '/finance', action: :paypal_ipn),
      'return' => url_for(controller: '/finance', action: :paypal_complete),
      'rm' => 1,
      'page_style' => 'icanlocalize'
    }
    make_uri(Figaro.env.PAYPAL_URLS, params)
  end
end
