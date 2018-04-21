class Vat

  def initialize(user, country_id = nil, vat_number = nil, total_cost = 0)
    @user = user
    @country = (country_id.to_i > 0 ? Country.find(country_id) : nil) || @user.country
    @vat_number = "#{@country.try(:code)}#{vat_number}" || @user.full_vat_number
    @vat_number_validated = false
    @has_valid_vat_number = false
    @total_cost = total_cost
  end

  def get_user_country
    @country
  end

  def vat_number_has_been_validated
    @vat_number_validated
  end

  def has_valid_vat_number
    return @has_valid_vat_number if @has_valid_vat_number
    is_valid = Eurovat.check_vat_number(@vat_number)
    @vat_number_validated = true
    @has_valid_vat_number = is_valid
  rescue StandardError => e
    @vat_number_validated = false
    @has_valid_vat_number = false
    Rails.logger.info "GENERAL ERROR WHILE CHECKING VAT FOR #{@vat_number}: #{e.message} : #{e.inspect}"
    false
  end

  def get_user_tax_rate
    tax_rate = @country.try(:tax_rate) || 0
    if @country.present?
      if @country.requiring_tax?
        tax_rate = 0 if has_valid_vat_number || !has_to_pay_tax
      end
    end
    tax_rate
  end

  def get_user_country_tax_amount
    tax_rate = ".#{get_user_tax_rate.to_i}".to_f
    tax_rate * @total_cost
  end

  def has_to_pay_tax
    has_to_pay = false
    if @country.present?
      return false if @user.exception_to_taxes
      if @country.requiring_tax?
        has_to_pay = true unless @has_valid_vat_number
      end
    end
    has_to_pay
  end

end
