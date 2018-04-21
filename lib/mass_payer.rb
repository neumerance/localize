require 'fileutils'

class MassPayer
  attr_reader :status
  attr_reader :save_file_name
  attr_reader :ok

  def self.file_name_for_receipt(receipt, save_folder)
    File.join(save_folder, "mass_payment_receipt_#{receipt.id}.txt")
  end

  def initialize(transactions, note, logger, save_folder = nil, fail_in_debug = false)
    @status = ''
    @logger = logger
    if transactions && !transactions.empty?
      curtime = Time.now
      withdrawal = nil
      mass_pay_data = []
      locked_transactions = []
      currency_name = nil
      original_transaction_status = {}
      for transaction in transactions
        next unless transaction.get_lock('MassPayer')
        unless withdrawal
          withdrawal = Withdrawal.create!(submit_time: curtime)
          logger.info "---------- created withdrawal #{withdrawal.id}"
          currency_name = transaction.currency.name
        end

        receipt = MassPaymentReceipt.new(status: TXN_CREATED, chgtime: curtime)
        receipt.withdrawal = withdrawal
        receipt.save!
        logger.info "----------- created receipt #{receipt.id}"

        # remember this, in case we need to rewind
        original_transaction_status[transaction.id] = transaction.status

        transaction.owner = receipt
        transaction.status = TRANSFER_PENDING
        transaction.save!

        mass_pay_data << [transaction.target_account.identifier,
                          transaction.amount,
                          receipt.id,
                          'Withdrawal from your ICanLocalize account']
        locked_transactions << transaction
      end

      if withdrawal
        if save_folder && (Rails.env != 'test')
          @save_file_name = MassPayer.file_name_for_receipt(receipt, save_folder) # File.join(save_folder, "mass_payment_receipt_#{receipt.id}")
          prepare_mass_pay_file(@save_file_name, currency_name, mass_pay_data)
          @ok = true
          @withdrawal = withdrawal
        elsif send_mass_pay(note, currency_name, mass_pay_data, fail_in_debug)
          @ok = true
          @withdrawal = withdrawal
        else
          # this will also destroy the mass_payment_receipt lines for this withdrawal
          withdrawal.destroy
          locked_transactions.each do |t|
            t.owner = nil
            t.status = original_transaction_status[t.id]
            t.save!
          end
        end
      else
        @status = "Couldn't lock any transaction"
      end

      # release the locked transactions
      locked_transactions.each(&:unlock)

    else
      @ok = false
      @status = 'No transactions to do'
    end
  end

  def send_mass_pay(note, currency_name, mass_pay_data, fail_in_debug)
    req = { method: 'MassPay',
            emailsubject: note,
            receivertype: 'EmailAddress' }

    groups = {}

    idx = 0
    for mass_pay_data_line in mass_pay_data
      groups["l_email#{idx}"] = mass_pay_data_line[0]
      groups["l_amt#{idx}"] = mass_pay_data_line[1]
      groups["l_uniqueid#{idx}"] = mass_pay_data_line[2]
      groups["l_note#{idx}"] = mass_pay_data_line[3]
      idx += 1
    end
    groups['CURRENCYCODE'] = currency_name

    @logger.info '--------- MASS PAYMENT ARGUMENTS:'
    groups.each { |k, v| @logger.info " > #{k}: #{v}" }

    req.update(groups)
    post_to_paypal(req, fail_in_debug)

  end

  def prepare_mass_pay_file(fname, currency_name, mass_pay_data)
    FileUtils.mkdir_p(File.dirname(fname))
    f = File.new(fname, 'w')
    mass_pay_data.each do |mass_pay_data_line|
      f.write("#{mass_pay_data_line[0]}\t#{mass_pay_data_line[1]}\t#{currency_name}\t#{mass_pay_data_line[2]}\t#{mass_pay_data_line[3]}\n")
    end
    f.close
  end

  def post_to_paypal(req, _fail_in_debug)
    caller = PayPalSdk::Callers::Caller.new(false)
    transaction = caller.call(req)
    @status = transaction.response
    transaction.success?
  end
end
