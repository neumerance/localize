FactoryGirl.define do
  factory :country, class: Country do

    trait :luxembourg do
      id 129
      code 'LU'
      name 'Luxembourg'
      language_id nil
      major 0
      tax_rate 17.0
      tax_name 'VAT'
      tax_group 'EU'
      tax_code 'LU'
    end

    trait :eu_country do
      code 'NL'
      name 'Netherlands'
      tax_rate 21.0
      tax_name 'VAT'
      tax_group 'EU'
      tax_code 'NL'
    end

    trait :non_eu_country do
      code 'PH'
      name 'Philippines'
      tax_code 'PH'
    end

    trait :spanish_country do
      code 'ES'
      name 'Spain'
      tax_rate 21.0
      tax_name 'VAT'
      tax_group 'EU'
      tax_code 'ES'
    end
  end
end
