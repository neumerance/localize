class CreateCurrencies < ActiveRecord::Migration
  def self.up
    create_table(:currencies, :options => 'ENGINE=InnoDB DEFAULT CHARSET=utf8') do |t|
      t.column :name, :string
      t.column :description, :string
      t.column :paypal_identifier, :string
      t.column :xchange, :decimal, {:precision=>8, :scale=>2, :default=>0}
    end
  end

  def self.down
    drop_table :currencies
  end
end
