require Rails.root.join('lib/mass_payer.rb')

class MassPayer
  def post_to_paypal(_req, fail_in_debug)
    if !fail_in_debug
      @status = 'Did it OK'
      true
    else
      @status = 'FAILED'
      false
    end
  end
end
