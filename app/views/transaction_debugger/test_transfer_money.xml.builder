xml.result(:ok=>@ok, :serial=>@serial, :amount=>@amount, :fee_rate=>@fee_rate) do
	xml.before do
		xml.from_balance(@before_from_balance)
		xml.to_balance(@before_to_balance)
		xml.root_balance(@before_root_balance)
		xml.total(@before_from_balance + @before_to_balance + @before_root_balance)
	end
	xml.after do
		xml.from_balance(@from_account.balance)
		xml.to_balance(@to_account.balance)
		xml.root_balance(@root_account.balance)
		xml.total(@from_account.balance + @to_account.balance + @root_account.balance)
	end
end