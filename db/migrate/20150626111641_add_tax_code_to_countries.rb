class AddTaxCodeToCountries < ActiveRecord::Migration
  def self.up
    add_column :countries, :tax_code, :string, {:limit => 3}

    Country.all.each { |c| c.update_attribute :tax_code, c.code }

    # side cases for vat
    Country.find_by_name('Greece').update_attribute :tax_code, 'EL'
  end

  def self.down
    remove_column :countries, :tax_code
  end
end
