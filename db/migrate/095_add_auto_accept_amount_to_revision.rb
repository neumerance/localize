class AddAutoAcceptAmountToRevision < ActiveRecord::Migration
	def self.up
		add_column :revisions, :auto_accept_amount, :decimal, {:precision=>8, :scale=>2, :default=>0}
	end

	def self.down
		remove_column :revisions, :auto_accept_amount
	end
end
