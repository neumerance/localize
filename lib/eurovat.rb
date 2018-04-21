# also useful: http://vatid.eu/
require 'thread'
require 'savon'

class Eurovat
  SERVICE_URL = 'http://ec.europa.eu/taxation_customs/vies/checkVatService.wsdl'.freeze
  VAT_FORMAT  = /\A([A-Z]{2})([0-9A-Za-z\+\*\.]{2,12})\Z/

  # Names must be consistent with the country_select plugin. If you know
  # alternative country spellings please add them here.
  EU_MEMBER_STATES = [
    'Austria',
    'Belgium',
    'Bulgaria',
    'Cyprus',
    'Czech Republic',
    'Denmark',
    'Estonia',
    'Finland',
    'France',
    'Germany',
    'Greece',
    'Hungary',
    'Ireland',
    'Italy',
    'Latvia',
    'Lithuania',
    'Luxembourg',
    'Malta',
    'Netherlands',
    'Poland',
    'Portugal',
    'Romania',
    'Slovakia',
    'Slovenia',
    'Spain',
    'Sweden',
    'United Kingdom'
  ].freeze

  class InvalidFormatError < StandardError
  end

  @@country  = 'Netherlands'
  @@instance = nil

  def self.country
    @@country
  end

  def self.country=(_val)
    @@country = country
  end

  def self.must_charge_vat?(customer_country, vat_number)
    # http://www.belastingdienst.nl/reken/diensten_in_en_uit_het_buitenland/
    if customer_country == @@country
      true
    else
      if present?(vat_number)
        false
      else
        EU_MEMBER_STATES.include?(customer_country)
      end
    end
  end

  def self.sanitize_vat_number(vat_number)
    vat_number.gsub(/[\s\t\.]/, '').upcase
  end

  def self.check_vat_number(vat_number)
    @@instance ||= new
    @@instance.check_vat_number(vat_number)
  end

  def initialize
    @country = @@country
    @mutex   = Mutex.new
    @driver = Savon.client(wsdl: SERVICE_URL)
  end

  # Any exception other than InvalidFormatError indicates that the service is down.
  def check_vat_number(vat_number)
    vat_number = Eurovat.sanitize_vat_number(vat_number)
    if vat_number =~ VAT_FORMAT
      country_code = $1
      number = $2
      @mutex.synchronize do
        begin
          resp = @driver.call :check_vat do
            message country_code: country_code, vat_number: number
          end
          data = resp.to_hash[:check_vat_response]
          data[:valid] #=> false :)
        rescue StandardError => e
          if e.message =~ /INVALID_INPUT/
            raise InvalidFormatError, "#{vat_number.inspect} is not formatted like a valid VAT number"
          else
            raise e
          end
        end
      end
    else
      raise InvalidFormatError, "#{vat_number.inspect} is not formatted like a valid VAT number"
    end
  end

  private_class_method
  def self.present?(val)
    if val.nil?
      false
    elsif val.is_a?(String)
      !val.empty?
    else
      !!val
    end
  end
end
