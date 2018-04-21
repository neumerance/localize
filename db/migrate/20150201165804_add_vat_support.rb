class AddVatSupport < ActiveRecord::Migration
  def self.up
      begin
        require 'ip_to_country.rb'
      rescue Exception => e
        # Also have to install geoip gem
        puts "\r\n\r\nPLEASE INSTALL GEOIP GEM: gem install geoip"  
        exit
      end
      
      add_column :countries, :tax_rate, :decimal, {:precision=>5, :scale=>2}
      add_column :countries, :tax_name, :string
      add_column :countries, :tax_group, :string

      add_column :users, :last_ip, :string
      add_column :users, :last_ip_country_id, :integer
      
      add_column :users, :vat_number, :string
      add_column :users, :is_business_vat, :boolean 

      # Fill data to countries
      taxes = {
        'Austria' => 20,
        'Belgium' => 21,
        'Bulgaria' => 20,
        'Hrvatska' => 25, #Croatia
        'Cyprus' => 19,
        'Czech Republic' => 21,
        'Denmark' => 25,
        'Estonia' => 20,
        'Finland' => 24,
        'France' => 20,
        'Germany' => 19,
        'Greece' => 23,
        'Hungary' => 27,
        'Ireland' => 23,
        'Italy' => 22,
        'Latvia' => 21,
        'Lithuania' => 21,
        'Luxembourg' => 17,
        'Malta' => 18,
        'Netherlands' => 21,
        'Poland' => 23,
        'Portugal' => 23,
        'Romania ' => 24,
        'Slovakia' => 20,
        'Slovenia' => 22,
        'Spain' => 21,
        'Sweden' => 25,
        'United Kingdom' => 20
      }

      taxes.each do |country_name, rate|
        country = Country.where(name: country_name).first
        raise "#{country_name} is an invalid country." unless country 
        country.update_attributes({:tax_rate => rate, :tax_name => 'VAT', :tax_group => 'EU'})
      end

      
      IpToCountry.setup
  end

  def self.down
    remove_columns :countries, :tax_rate, :tax_name, :tax_group
    remove_columns :users, :last_ip, :last_ip_country_id, :vat_number, :is_business_vat
  end
end
