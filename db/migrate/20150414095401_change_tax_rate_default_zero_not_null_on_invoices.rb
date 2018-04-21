class ChangeTaxRateDefaultZeroNotNullOnInvoices < ActiveRecord::Migration
  def self.up
    change_column_null :invoices, :tax_rate, false
    change_column_default :invoices, :tax_rate, 0
  end

  def self.down
    change_column_null :invoices, :tax_rate, true
    change_column_default :invoices, :tax_rate, nil
  end
end
