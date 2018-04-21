require '../../components/transaction_processor.rb'
include TransactionProcessor

total_balance = 10000

# Create table to hold transaction information
ActiveRecord::Base.connection.execute('create table transaction_history (id int NOT NULL PRIMARY KEY AUTO_INCREMENT, from_id int, to_id int, affiliate_id int, took_amount float, received_amount float, affiliate_amount float)')

# Create 10 money accounts
money_accounts = []
10.times do |x|
  user = NormalUser.create!(password: '123456789', email: "user#{x}@email.com", nickname: "user#{x}", fname: 'fname', lname: 'lname')
  money_accounts << UserAccount.create!(currency_id: DEFAULT_CURRENCY_ID, balance: total_balance / 10, owner_id: user.id)
end

threads = []
4.times do
  threads << Thread.new do
    1000.times do
      n1 = rand(10)
      n2 = n1
      n3 = n1
      n2 = rand(10) while n2 == n1
      n3 = rand(10) while [n1, n2].include? n3

      from = money_accounts[n1]
      to = money_accounts[n2]
      amount = rand(1000)
      type = TRANSFER_TYPES[rand(TRANSFER_TYPES.size)]
      fee = rand(5) * 0.01
      affiliate_user = money_accounts[n3].normal_user
      attribute = :balance
      owner = nil
      begin
        # raise if transfer_money(from, to, amount, DEFAULT_CURRENCY_ID, type, fee, affiliate_user).nil?
        MoneyTransactionProcessor.transfer_money(from.reload, to.reload, amount, 0, type, fee, affiliate_user, attribute, owner)
        ActiveRecord::Base.connection.execute("INSERT INTO transaction_history
                                              (from_id, to_id, affiliate_id, took_amount, received_amount, affiliate_amount) values
                                              ('#{from.id}','#{to.id}','#{affiliate_user.money_accounts.first.id}','#{amount}','#{amount - (amount * fee)}',
                                              '#{amount * (fee * AFFILIATE_COMMISSION_RATE)}')")
        puts 'transfer ok'
      rescue => e
        puts 'transfer error'
        puts e.inspect
        # Don't care if it don't have balance or fail - in the end, it should keep consistent.
      end
    end
  end
end
threads.each(&:join)
sleep 2

root_account = RootAccount.find_or_create
puts total_balance, money_accounts.inject(0) { |a, b| b.reload; a + b.balance.to_f } + root_account.balance
puts '==='

records = ActiveRecord::Base.connection.execute('select * from transaction_history order by id')
amount_sum_per_account = Hash.new(total_balance / 10)
records.each do |r|
  amount_sum_per_account[r[1]] -= r[4].to_f
  amount_sum_per_account[r[2]] += r[5].to_f
  amount_sum_per_account[r[3]] += r[6].to_f
end

puts "ID\t| REAL\t   |TEST"
puts '==========================='
amount_sum_per_account.each_pair do |k, v|
  puts "#{k}\t| %05.2f\t| #{v}" % MoneyAccount.find(k).balance.to_f
end
