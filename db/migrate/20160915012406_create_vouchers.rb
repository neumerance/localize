class CreateVouchers < ActiveRecord::Migration
  def self.up
    create_table(:vouchers) do |t|
      t.column :code, :string
      t.column :active, :boolean
      t.column :amount, :decimal, :precision => 8, :scale => 2, :default => 0.0
      t.column :comments, :text
    end

    create_table(:clients_vouchers, :id => false) do |t|
      t.column :client_id, :integer
      t.column :voucher_id, :integer
    end
    add_index "clients_vouchers", ["client_id", "voucher_id"], :name => "used_vouchers", :unique => true
  end

  def self.down
    drop_table :vouchers
    drop_table :clients_vouchers
  end
end
