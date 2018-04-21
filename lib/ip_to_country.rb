require 'geoip'

class IpToCountry
  DB_URL  = 'http://geolite.maxmind.com/download/geoip/database/GeoLiteCity.dat.gz'.freeze
  DB_PATH = Rails.root.join('private', 'GeoLiteCity.dat')

  def self.setup(force = false)
    if !force && File.exist?(DB_PATH)
      return Rails.logger.info 'IpToCountry DB Already exist, skipping setup'
    end

    puts "Downloading db to #{DB_PATH}..."
    `wget -O #{DB_PATH}.gz #{DB_URL}`
    `gzip -d #{DB_PATH}.gz`
  end

  def self.country(ip)
    GeoIP.new(DB_PATH).country(ip)
  end

  def self.get_country_code(ip)

    c = country(ip).country_code2
  rescue Exception => e

  end
end
