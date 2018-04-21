import random, sys, threading, time
import server_access

# http://icanlocalize.local/transaction_debugger/test_transfer_money.xml?from_account_id=1&to_account_id=2&currency_id=1&amount=12.3&operation_code=1&fee_rate=0.3

def proc_result(e):
    root = e.getroot()
    ok = root.attrib['ok']
    res = e.find("result")
    #if ok != 'true':
    #    print "Didn't find the result field. Returned HTML in 'err.html'"
    #    f = open("err.xml","w")
    #    print e.write(f)
    #    f.close()
    #    print "\nLast query:\n%s"%sys.lastquery
    #    #sys.exit()
    return ok == 'true'

class calls_maker(threading.Thread):
    def set_args(self, server_id, tests, from_account_id, to_account_id, currency_id, operation_code):
        self.params = { 'server_id' : server_id,
                        'from_account_id' : from_account_id,
                        'to_account_id' : to_account_id,
                        'currency_id' : currency_id,
                        'operation_code' : operation_code }
        self.tests = tests
        self.from_sub = 0
        self.to_add = 0
        self.fee_add = 0

    def run(self):

        for i in range(self.tests):
            amount = random.randint(200,1000) / 100
            fee_rate = random.randint(0,99) / 100.0
            self.params['amount'] = amount
            self.params['fee_rate'] = fee_rate
            self.params['serial'] = i

            fee = amount * fee_rate
            net = amount - fee

            self.from_sub += amount
            self.to_add += net
            self.fee_add += fee
            
            result = server_access.call('transaction_debugger', 'test_transfer_money', self.params, post=False)
            proc_result(result)

# test runs
ins_num = 5 
tests = 60 

# account definition
from_account_id = 1
to_account_id = 2
currency_id = 1
operation_code = 1

# reset the account lines history
print "Clearing server history."
server_access.call('transaction_debugger', 'clear_account_lines', {}, post=False)

balances = {}
orig_total = 0
# before the test runs, set the balance
print "Initializing account balances."
params = {}
for account in [from_account_id, to_account_id]:
    balance = 100000
    params['account_id'] = account
    params['balance'] = balance
    balances[account] = balance
    server_access.call('transaction_debugger', 'set_balance', params, post=False)
    orig_total += balance

root_balance = 0
params = {}
params['balance'] = root_balance
params['currency_id'] = currency_id
server_access.call('transaction_debugger', 'set_root_balance', params, post=False)

orig_total += root_balance



print "Running %d iterations on %d instances"%(tests, ins_num)
start_time = time.time()

instances = []
for idx in range(ins_num):
    ins = calls_maker()
    ins.set_args(idx, tests, from_account_id, to_account_id, currency_id, operation_code)
    ins.start()
    instances.append(ins)

someone_running = True
while someone_running:
    time.sleep(1)
    someone_running = False
    for ins in instances:
        if ins.isAlive():
            someone_running = True

end_time = time.time()
elapsed_time = end_time - start_time
print "Test took %f seconds - %f ms per request."%(elapsed_time, 1000.0*elapsed_time/(ins_num*tests))

# calculate the expected balance in each account
from_sub = 0
to_add = 0
fee_add = 0
for ins in instances:
    from_sub += ins.from_sub
    to_add += ins.to_add
    fee_add += ins.fee_add

expected_balance = {}
expected_balance[from_account_id] = balances[from_account_id] - from_sub
expected_balance[to_account_id] = balances[to_account_id] + to_add
expected_root_balance = root_balance + fee_add

# prepare the summary result
failed = False

# show the balance of each
print "\nCollecting final balance.\n"
total = 0
for account in [from_account_id, to_account_id]:
    params['account_id'] = account
    result = server_access.call('transaction_debugger', 'get_balance', params, post=False)

    root = result.getroot()
    balance = float(root.attrib['balance'])
    total += balance
    if abs(balance - expected_balance[account]) <= 0.02:
        print "account %d matches. Balance = %f"%(account, balance)
    else:
        print "account %d MISMATCH: Balance = %f, Expected = %f"%(account, balance, expected_balance[account])
        failed = True

params = { 'currency_id' : currency_id }
result = server_access.call('transaction_debugger', 'get_root_balance', params, post=False)
root = result.getroot()
final_root_balance = float(root.attrib['balance'])
total += final_root_balance

if abs(final_root_balance - expected_root_balance) <= 0.02:
    print "Fee account matched. Balance = %f"%final_root_balance
else:
    print "Fee account MISMATCH. Balance = %f, Expected = %f"%(final_root_balance,expected_root_balance)
    failed = True

print

if abs(orig_total - total) <= 0.02:
    print "Total balance OK: %f\n"%total
else:
    print "Total balance check failed. Starting total = %f, current total = %f\n"%(orig_total, total)
    failed = True


# do the account integrity check
for account in [from_account_id, to_account_id]:
    params = { 'account_id' : account,
               'initial_balance' : balances[account] }
    result = server_access.call('transaction_debugger', 'check_account_integrity', params, post=False)
    root = result.getroot()
    zero_addition = root.attrib['zero_addition']
    ending_balance_ok = root.attrib['ending_balance_ok']
    balance_mismatch = root.attrib['balance_mismatch']
    res = (zero_addition == 'false') and (ending_balance_ok == 'true') and (balance_mismatch == 'false')
    print "Account: %d - zero_addition: %s, ending_balance_ok: %s, balance_mismatch: %s"%(account, zero_addition, ending_balance_ok, balance_mismatch)
    if not res:
        failed = True

if not failed:
    print "\n\n ----------- Test passed ------------- \n"
else:
    print "\n\n ----------- TEST FAILED ------------- \n"
    
