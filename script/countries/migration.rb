def self.up
  country = Country.where("code = 'AD'").first
  Country.create(code: 'AD', name: 'Andorra', major: 0) unless country

  country = Country.where("code = 'AE'").first
  unless country
    Country.create(code: 'AE', name: 'United Arab Emirates', major: 0)
  end

  country = Country.where("code = 'AF'").first
  Country.create(code: 'AF', name: 'Afghanistan', major: 0) unless country

  country = Country.where("code = 'AG'").first
  unless country
    Country.create(code: 'AG', name: 'Antigua and Barbuda', major: 0)
  end

  country = Country.where("code = 'AI'").first
  Country.create(code: 'AI', name: 'Anguilla', major: 0) unless country

  country = Country.where("code = 'AL'").first
  Country.create(code: 'AL', name: 'Albania', major: 0) unless country

  country = Country.where("code = 'AM'").first
  Country.create(code: 'AM', name: 'Armenia', major: 0) unless country

  country = Country.where("code = 'AN'").first
  unless country
    Country.create(code: 'AN', name: 'Netherlands Antilles', major: 0)
  end

  country = Country.where("code = 'AO'").first
  Country.create(code: 'AO', name: 'Angola', major: 0) unless country

  country = Country.where("code = 'AQ'").first
  Country.create(code: 'AQ', name: 'Antarctica', major: 0) unless country

  country = Country.where("code = 'AR'").first
  Country.create(code: 'AR', name: 'Argentina', major: 0) unless country

  country = Country.where("code = 'AS'").first
  Country.create(code: 'AS', name: 'American Samoa', major: 0) unless country

  country = Country.where("code = 'AT'").first
  Country.create(code: 'AT', name: 'Austria', major: 0) unless country

  country = Country.where("code = 'AU'").first
  Country.create(code: 'AU', name: 'Australia', major: 1) unless country

  country = Country.where("code = 'AW'").first
  Country.create(code: 'AW', name: 'Aruba', major: 0) unless country

  country = Country.where("code = 'AZ'").first
  Country.create(code: 'AZ', name: 'Azerbaijan', major: 0) unless country

  country = Country.where("code = 'BA'").first
  unless country
    Country.create(code: 'BA', name: 'Bosnia and Herzegovina', major: 0)
  end

  country = Country.where("code = 'BB'").first
  Country.create(code: 'BB', name: 'Barbados', major: 0) unless country

  country = Country.where("code = 'BD'").first
  Country.create(code: 'BD', name: 'Bangladesh', major: 0) unless country

  country = Country.where("code = 'BE'").first
  Country.create(code: 'BE', name: 'Belgium', major: 0) unless country

  country = Country.where("code = 'BF'").first
  Country.create(code: 'BF', name: 'Burkina Faso', major: 0) unless country

  country = Country.where("code = 'BG'").first
  Country.create(code: 'BG', name: 'Bulgaria', major: 0) unless country

  country = Country.where("code = 'BH'").first
  Country.create(code: 'BH', name: 'Bahrain', major: 0) unless country

  country = Country.where("code = 'BI'").first
  Country.create(code: 'BI', name: 'Burundi', major: 0) unless country

  country = Country.where("code = 'BJ'").first
  Country.create(code: 'BJ', name: 'Benin', major: 0) unless country

  country = Country.where("code = 'BM'").first
  Country.create(code: 'BM', name: 'Bermuda', major: 0) unless country

  country = Country.where("code = 'BN'").first
  Country.create(code: 'BN', name: 'Brunei Darussalam', major: 0) unless country

  country = Country.where("code = 'BO'").first
  Country.create(code: 'BO', name: 'Bolivia', major: 0) unless country

  country = Country.where("code = 'BR'").first
  Country.create(code: 'BR', name: 'Brazil', major: 0) unless country

  country = Country.where("code = 'BS'").first
  Country.create(code: 'BS', name: 'Bahamas', major: 0) unless country

  country = Country.where("code = 'BT'").first
  Country.create(code: 'BT', name: 'Bhutan', major: 0) unless country

  country = Country.where("code = 'BV'").first
  Country.create(code: 'BV', name: 'Bouvet Island', major: 0) unless country

  country = Country.where("code = 'BW'").first
  Country.create(code: 'BW', name: 'Botswana', major: 0) unless country

  country = Country.where("code = 'BY'").first
  Country.create(code: 'BY', name: 'Belarus', major: 0) unless country

  country = Country.where("code = 'BZ'").first
  Country.create(code: 'BZ', name: 'Belize', major: 0) unless country

  country = Country.where("code = 'CA'").first
  Country.create(code: 'CA', name: 'Canada', major: 1) unless country

  country = Country.where("code = 'CC'").first
  Country.create(code: 'CC', name: 'Cocos  Islands', major: 0) unless country

  country = Country.where("code = 'CD'").first
  Country.create(code: 'CD', name: 'Congo', major: 0) unless country

  country = Country.where("code = 'CF'").first
  unless country
    Country.create(code: 'CF', name: 'Central African Republic', major: 0)
  end

  country = Country.where("code = 'CG'").first
  Country.create(code: 'CG', name: 'Congo', major: 0) unless country

  country = Country.where("code = 'CH'").first
  Country.create(code: 'CH', name: 'Switzerland', major: 0) unless country

  country = Country.where("code = 'CI'").first
  Country.create(code: 'CI', name: "Cote D'Ivoire", major: 0) unless country

  country = Country.where("code = 'CK'").first
  Country.create(code: 'CK', name: 'Cook Islands', major: 0) unless country

  country = Country.where("code = 'CL'").first
  Country.create(code: 'CL', name: 'Chile', major: 0) unless country

  country = Country.where("code = 'CM'").first
  Country.create(code: 'CM', name: 'Cameroon', major: 0) unless country

  country = Country.where("code = 'CN'").first
  Country.create(code: 'CN', name: 'China', major: 0) unless country

  country = Country.where("code = 'CO'").first
  Country.create(code: 'CO', name: 'Colombia', major: 0) unless country

  country = Country.where("code = 'CR'").first
  Country.create(code: 'CR', name: 'Costa Rica', major: 0) unless country

  country = Country.where("code = 'CS'").first
  unless country
    Country.create(code: 'CS', name: 'Serbia and Montenegro', major: 0)
  end

  country = Country.where("code = 'CU'").first
  Country.create(code: 'CU', name: 'Cuba', major: 0) unless country

  country = Country.where("code = 'CV'").first
  Country.create(code: 'CV', name: 'Cape Verde', major: 0) unless country

  country = Country.where("code = 'CX'").first
  Country.create(code: 'CX', name: 'Christmas Island', major: 0) unless country

  country = Country.where("code = 'CY'").first
  Country.create(code: 'CY', name: 'Cyprus', major: 0) unless country

  country = Country.where("code = 'CZ'").first
  Country.create(code: 'CZ', name: 'Czech Republic', major: 0) unless country

  country = Country.where("code = 'DE'").first
  Country.create(code: 'DE', name: 'Germany', major: 1) unless country

  country = Country.where("code = 'DJ'").first
  Country.create(code: 'DJ', name: 'Djibouti', major: 0) unless country

  country = Country.where("code = 'DK'").first
  Country.create(code: 'DK', name: 'Denmark', major: 0) unless country

  country = Country.where("code = 'DM'").first
  Country.create(code: 'DM', name: 'Dominica', major: 0) unless country

  country = Country.where("code = 'DO'").first
  unless country
    Country.create(code: 'DO', name: 'Dominican Republic', major: 0)
  end

  country = Country.where("code = 'DZ'").first
  Country.create(code: 'DZ', name: 'Algeria', major: 0) unless country

  country = Country.where("code = 'EC'").first
  Country.create(code: 'EC', name: 'Ecuador', major: 0) unless country

  country = Country.where("code = 'EE'").first
  Country.create(code: 'EE', name: 'Estonia', major: 0) unless country

  country = Country.where("code = 'EG'").first
  Country.create(code: 'EG', name: 'Egypt', major: 0) unless country

  country = Country.where("code = 'EH'").first
  Country.create(code: 'EH', name: 'Western Sahara', major: 0) unless country

  country = Country.where("code = 'ER'").first
  Country.create(code: 'ER', name: 'Eritrea', major: 0) unless country

  country = Country.where("code = 'ES'").first
  Country.create(code: 'ES', name: 'Spain', major: 0) unless country

  country = Country.where("code = 'ET'").first
  Country.create(code: 'ET', name: 'Ethiopia', major: 0) unless country

  country = Country.where("code = 'FI'").first
  Country.create(code: 'FI', name: 'Finland', major: 0) unless country

  country = Country.where("code = 'FJ'").first
  Country.create(code: 'FJ', name: 'Fiji', major: 0) unless country

  country = Country.where("code = 'FK'").first
  Country.create(code: 'FK', name: 'Falkland Islands', major: 0) unless country

  country = Country.where("code = 'FM'").first
  Country.create(code: 'FM', name: 'Micronesia', major: 0) unless country

  country = Country.where("code = 'FO'").first
  Country.create(code: 'FO', name: 'Faeroe Islands', major: 0) unless country

  country = Country.where("code = 'FR'").first
  Country.create(code: 'FR', name: 'France', major: 1) unless country

  country = Country.where("code = 'GA'").first
  Country.create(code: 'GA', name: 'Gabon', major: 0) unless country

  country = Country.where("code = 'GB'").first
  Country.create(code: 'GB', name: 'United Kingdom', major: 1) unless country

  country = Country.where("code = 'GD'").first
  Country.create(code: 'GD', name: 'Grenada', major: 0) unless country

  country = Country.where("code = 'GE'").first
  Country.create(code: 'GE', name: 'Georgia', major: 0) unless country

  country = Country.where("code = 'GF'").first
  Country.create(code: 'GF', name: 'French Guiana', major: 0) unless country

  country = Country.where("code = 'GH'").first
  Country.create(code: 'GH', name: 'Ghana', major: 0) unless country

  country = Country.where("code = 'GI'").first
  Country.create(code: 'GI', name: 'Gibraltar', major: 0) unless country

  country = Country.where("code = 'GL'").first
  Country.create(code: 'GL', name: 'Greenland', major: 0) unless country

  country = Country.where("code = 'GM'").first
  Country.create(code: 'GM', name: 'Gambia', major: 0) unless country

  country = Country.where("code = 'GN'").first
  Country.create(code: 'GN', name: 'Guinea', major: 0) unless country

  country = Country.where("code = 'GP'").first
  Country.create(code: 'GP', name: 'Guadaloupe', major: 0) unless country

  country = Country.where("code = 'GQ'").first
  Country.create(code: 'GQ', name: 'Equatorial Guinea', major: 0) unless country

  country = Country.where("code = 'GR'").first
  Country.create(code: 'GR', name: 'Greece', major: 0) unless country

  country = Country.where("code = 'GS'").first
  unless country
    Country.create(code: 'GS', name: 'South Georgia and the South Sandwich Islands', major: 0)
  end

  country = Country.where("code = 'GT'").first
  Country.create(code: 'GT', name: 'Guatemala', major: 0) unless country

  country = Country.where("code = 'GU'").first
  Country.create(code: 'GU', name: 'Guam', major: 0) unless country

  country = Country.where("code = 'GW'").first
  Country.create(code: 'GW', name: 'Guinea-Bissau', major: 0) unless country

  country = Country.where("code = 'GY'").first
  Country.create(code: 'GY', name: 'Guyana', major: 0) unless country

  country = Country.where("code = 'HK'").first
  Country.create(code: 'HK', name: 'Hong Kong', major: 0) unless country

  country = Country.where("code = 'HM'").first
  unless country
    Country.create(code: 'HM', name: 'Heard and McDonald Islands', major: 0)
  end

  country = Country.where("code = 'HN'").first
  Country.create(code: 'HN', name: 'Honduras', major: 0) unless country

  country = Country.where("code = 'HR'").first
  Country.create(code: 'HR', name: 'Hrvatska', major: 0) unless country

  country = Country.where("code = 'HT'").first
  Country.create(code: 'HT', name: 'Haiti', major: 0) unless country

  country = Country.where("code = 'HU'").first
  Country.create(code: 'HU', name: 'Hungary', major: 0) unless country

  country = Country.where("code = 'ID'").first
  Country.create(code: 'ID', name: 'Indonesia', major: 0) unless country

  country = Country.where("code = 'IE'").first
  Country.create(code: 'IE', name: 'Ireland', major: 0) unless country

  country = Country.where("code = 'IL'").first
  Country.create(code: 'IL', name: 'Israel', major: 0) unless country

  country = Country.where("code = 'IN'").first
  Country.create(code: 'IN', name: 'India', major: 0) unless country

  country = Country.where("code = 'IO'").first
  unless country
    Country.create(code: 'IO', name: 'British Indian Ocean Territory', major: 0)
  end

  country = Country.where("code = 'IQ'").first
  Country.create(code: 'IQ', name: 'Iraq', major: 0) unless country

  country = Country.where("code = 'IR'").first
  Country.create(code: 'IR', name: 'Iran', major: 0) unless country

  country = Country.where("code = 'IS'").first
  Country.create(code: 'IS', name: 'Iceland', major: 0) unless country

  country = Country.where("code = 'IT'").first
  Country.create(code: 'IT', name: 'Italy', major: 0) unless country

  country = Country.where("code = 'JM'").first
  Country.create(code: 'JM', name: 'Jamaica', major: 0) unless country

  country = Country.where("code = 'JO'").first
  Country.create(code: 'JO', name: 'Jordan', major: 0) unless country

  country = Country.where("code = 'JP'").first
  Country.create(code: 'JP', name: 'Japan', major: 0) unless country

  country = Country.where("code = 'KE'").first
  Country.create(code: 'KE', name: 'Kenya', major: 0) unless country

  country = Country.where("code = 'KG'").first
  Country.create(code: 'KG', name: 'Kyrgyz Republic', major: 0) unless country

  country = Country.where("code = 'KH'").first
  Country.create(code: 'KH', name: 'Cambodia', major: 0) unless country

  country = Country.where("code = 'KI'").first
  Country.create(code: 'KI', name: 'Kiribati', major: 0) unless country

  country = Country.where("code = 'KM'").first
  Country.create(code: 'KM', name: 'Comoros', major: 0) unless country

  country = Country.where("code = 'KN'").first
  unless country
    Country.create(code: 'KN', name: 'St. Kitts and Nevis', major: 0)
  end

  country = Country.where("code = 'KP'").first
  Country.create(code: 'KP', name: 'Korea', major: 0) unless country

  country = Country.where("code = 'KR'").first
  Country.create(code: 'KR', name: 'Korea', major: 0) unless country

  country = Country.where("code = 'KW'").first
  Country.create(code: 'KW', name: 'Kuwait', major: 0) unless country

  country = Country.where("code = 'KY'").first
  Country.create(code: 'KY', name: 'Cayman Islands', major: 0) unless country

  country = Country.where("code = 'KZ'").first
  Country.create(code: 'KZ', name: 'Kazakhstan', major: 0) unless country

  country = Country.where("code = 'LA'").first
  unless country
    Country.create(code: 'LA', name: "Lao People's Democratic Republic", major: 0)
  end

  country = Country.where("code = 'LB'").first
  Country.create(code: 'LB', name: 'Lebanon', major: 0) unless country

  country = Country.where("code = 'LC'").first
  Country.create(code: 'LC', name: 'St. Lucia', major: 0) unless country

  country = Country.where("code = 'LI'").first
  Country.create(code: 'LI', name: 'Liechtenstein', major: 0) unless country

  country = Country.where("code = 'LK'").first
  Country.create(code: 'LK', name: 'Sri Lanka', major: 0) unless country

  country = Country.where("code = 'LR'").first
  Country.create(code: 'LR', name: 'Liberia', major: 0) unless country

  country = Country.where("code = 'LS'").first
  Country.create(code: 'LS', name: 'Lesotho', major: 0) unless country

  country = Country.where("code = 'LT'").first
  Country.create(code: 'LT', name: 'Lithuania', major: 0) unless country

  country = Country.where("code = 'LU'").first
  Country.create(code: 'LU', name: 'Luxembourg', major: 0) unless country

  country = Country.where("code = 'LV'").first
  Country.create(code: 'LV', name: 'Latvia', major: 0) unless country

  country = Country.where("code = 'LY'").first
  unless country
    Country.create(code: 'LY', name: 'Libyan Arab Jamahiriya', major: 0)
  end

  country = Country.where("code = 'MA'").first
  Country.create(code: 'MA', name: 'Morocco', major: 0) unless country

  country = Country.where("code = 'MC'").first
  Country.create(code: 'MC', name: 'Monaco', major: 0) unless country

  country = Country.where("code = 'MD'").first
  Country.create(code: 'MD', name: 'Moldova', major: 0) unless country

  country = Country.where("code = 'MG'").first
  Country.create(code: 'MG', name: 'Madagascar', major: 0) unless country

  country = Country.where("code = 'MH'").first
  Country.create(code: 'MH', name: 'Marshall Islands', major: 0) unless country

  country = Country.where("code = 'MK'").first
  Country.create(code: 'MK', name: 'Macedonia', major: 0) unless country

  country = Country.where("code = 'ML'").first
  Country.create(code: 'ML', name: 'Mali', major: 0) unless country

  country = Country.where("code = 'MM'").first
  Country.create(code: 'MM', name: 'Myanmar', major: 0) unless country

  country = Country.where("code = 'MN'").first
  Country.create(code: 'MN', name: 'Mongolia', major: 0) unless country

  country = Country.where("code = 'MO'").first
  Country.create(code: 'MO', name: 'Macao', major: 0) unless country

  country = Country.where("code = 'MP'").first
  unless country
    Country.create(code: 'MP', name: 'Northern Mariana Islands', major: 0)
  end

  country = Country.where("code = 'MQ'").first
  Country.create(code: 'MQ', name: 'Martinique', major: 0) unless country

  country = Country.where("code = 'MR'").first
  Country.create(code: 'MR', name: 'Mauritania', major: 0) unless country

  country = Country.where("code = 'MS'").first
  Country.create(code: 'MS', name: 'Montserrat', major: 0) unless country

  country = Country.where("code = 'MT'").first
  Country.create(code: 'MT', name: 'Malta', major: 0) unless country

  country = Country.where("code = 'MU'").first
  Country.create(code: 'MU', name: 'Mauritius', major: 0) unless country

  country = Country.where("code = 'MV'").first
  Country.create(code: 'MV', name: 'Maldives', major: 0) unless country

  country = Country.where("code = 'MW'").first
  Country.create(code: 'MW', name: 'Malawi', major: 0) unless country

  country = Country.where("code = 'MX'").first
  Country.create(code: 'MX', name: 'Mexico', major: 0) unless country

  country = Country.where("code = 'MY'").first
  Country.create(code: 'MY', name: 'Malaysia', major: 0) unless country

  country = Country.where("code = 'MZ'").first
  Country.create(code: 'MZ', name: 'Mozambique', major: 0) unless country

  country = Country.where("code = 'NA'").first
  Country.create(code: 'NA', name: 'Namibia', major: 0) unless country

  country = Country.where("code = 'NC'").first
  Country.create(code: 'NC', name: 'New Caledonia', major: 0) unless country

  country = Country.where("code = 'NE'").first
  Country.create(code: 'NE', name: 'Niger', major: 0) unless country

  country = Country.where("code = 'NF'").first
  Country.create(code: 'NF', name: 'Norfolk Island', major: 0) unless country

  country = Country.where("code = 'NG'").first
  Country.create(code: 'NG', name: 'Nigeria', major: 0) unless country

  country = Country.where("code = 'NI'").first
  Country.create(code: 'NI', name: 'Nicaragua', major: 0) unless country

  country = Country.where("code = 'NL'").first
  Country.create(code: 'NL', name: 'Netherlands', major: 0) unless country

  country = Country.where("code = 'NO'").first
  Country.create(code: 'NO', name: 'Norway', major: 0) unless country

  country = Country.where("code = 'NP'").first
  Country.create(code: 'NP', name: 'Nepal', major: 0) unless country

  country = Country.where("code = 'NR'").first
  Country.create(code: 'NR', name: 'Nauru', major: 0) unless country

  country = Country.where("code = 'NU'").first
  Country.create(code: 'NU', name: 'Niue', major: 0) unless country

  country = Country.where("code = 'NZ'").first
  Country.create(code: 'NZ', name: 'New Zealand', major: 0) unless country

  country = Country.where("code = 'OM'").first
  Country.create(code: 'OM', name: 'Oman', major: 0) unless country

  country = Country.where("code = 'PA'").first
  Country.create(code: 'PA', name: 'Panama', major: 0) unless country

  country = Country.where("code = 'PE'").first
  Country.create(code: 'PE', name: 'Peru', major: 0) unless country

  country = Country.where("code = 'PF'").first
  Country.create(code: 'PF', name: 'French Polynesia', major: 0) unless country

  country = Country.where("code = 'PG'").first
  Country.create(code: 'PG', name: 'Papua New Guinea', major: 0) unless country

  country = Country.where("code = 'PH'").first
  Country.create(code: 'PH', name: 'Philippines', major: 0) unless country

  country = Country.where("code = 'PK'").first
  Country.create(code: 'PK', name: 'Pakistan', major: 0) unless country

  country = Country.where("code = 'PL'").first
  Country.create(code: 'PL', name: 'Poland', major: 0) unless country

  country = Country.where("code = 'PM'").first
  unless country
    Country.create(code: 'PM', name: 'St. Pierre and Miquelon', major: 0)
  end

  country = Country.where("code = 'PN'").first
  Country.create(code: 'PN', name: 'Pitcairn Island', major: 0) unless country

  country = Country.where("code = 'PR'").first
  Country.create(code: 'PR', name: 'Puerto Rico', major: 0) unless country

  country = Country.where("code = 'PS'").first
  unless country
    Country.create(code: 'PS', name: 'Palestinian Territory', major: 0)
  end

  country = Country.where("code = 'PT'").first
  Country.create(code: 'PT', name: 'Portugal', major: 0) unless country

  country = Country.where("code = 'PW'").first
  Country.create(code: 'PW', name: 'Palau', major: 0) unless country

  country = Country.where("code = 'PY'").first
  Country.create(code: 'PY', name: 'Paraguay', major: 0) unless country

  country = Country.where("code = 'QA'").first
  Country.create(code: 'QA', name: 'Qatar', major: 0) unless country

  country = Country.where("code = 'RE'").first
  Country.create(code: 'RE', name: 'Reunion', major: 0) unless country

  country = Country.where("code = 'RO'").first
  Country.create(code: 'RO', name: 'Romania', major: 0) unless country

  country = Country.where("code = 'RU'").first
  unless country
    Country.create(code: 'RU', name: 'Russian Federation', major: 0)
  end

  country = Country.where("code = 'RW'").first
  Country.create(code: 'RW', name: 'Rwanda', major: 0) unless country

  country = Country.where("code = 'SA'").first
  Country.create(code: 'SA', name: 'Saudi Arabia', major: 0) unless country

  country = Country.where("code = 'SB'").first
  Country.create(code: 'SB', name: 'Solomon Islands', major: 0) unless country

  country = Country.where("code = 'SC'").first
  Country.create(code: 'SC', name: 'Seychelles', major: 0) unless country

  country = Country.where("code = 'SD'").first
  Country.create(code: 'SD', name: 'Sudan', major: 0) unless country

  country = Country.where("code = 'SE'").first
  Country.create(code: 'SE', name: 'Sweden', major: 0) unless country

  country = Country.where("code = 'SG'").first
  Country.create(code: 'SG', name: 'Singapore', major: 0) unless country

  country = Country.where("code = 'SH'").first
  Country.create(code: 'SH', name: 'St. Helena', major: 0) unless country

  country = Country.where("code = 'SI'").first
  Country.create(code: 'SI', name: 'Slovenia', major: 0) unless country

  country = Country.where("code = 'SJ'").first
  unless country
    Country.create(code: 'SJ', name: 'Svalbard & Jan Mayen Islands', major: 0)
  end

  country = Country.where("code = 'SK'").first
  Country.create(code: 'SK', name: 'Slovakia', major: 0) unless country

  country = Country.where("code = 'SL'").first
  Country.create(code: 'SL', name: 'Sierra Leone', major: 0) unless country

  country = Country.where("code = 'SM'").first
  Country.create(code: 'SM', name: 'San Marino', major: 0) unless country

  country = Country.where("code = 'SN'").first
  Country.create(code: 'SN', name: 'Senegal', major: 0) unless country

  country = Country.where("code = 'SO'").first
  Country.create(code: 'SO', name: 'Somalia', major: 0) unless country

  country = Country.where("code = 'SR'").first
  Country.create(code: 'SR', name: 'Suriname', major: 0) unless country

  country = Country.where("code = 'ST'").first
  unless country
    Country.create(code: 'ST', name: 'Sao Tome and Principe', major: 0)
  end

  country = Country.where("code = 'SV'").first
  Country.create(code: 'SV', name: 'El Salvador', major: 0) unless country

  country = Country.where("code = 'SY'").first
  unless country
    Country.create(code: 'SY', name: 'Syrian Arab Republic', major: 0)
  end

  country = Country.where("code = 'SZ'").first
  Country.create(code: 'SZ', name: 'Swaziland', major: 0) unless country

  country = Country.where("code = 'TC'").first
  unless country
    Country.create(code: 'TC', name: 'Turks and Caicos Islands', major: 0)
  end

  country = Country.where("code = 'TD'").first
  Country.create(code: 'TD', name: 'Chad', major: 0) unless country

  country = Country.where("code = 'TF'").first
  unless country
    Country.create(code: 'TF', name: 'French Southern Territories', major: 0)
  end

  country = Country.where("code = 'TG'").first
  Country.create(code: 'TG', name: 'Togo', major: 0) unless country

  country = Country.where("code = 'TH'").first
  Country.create(code: 'TH', name: 'Thailand', major: 0) unless country

  country = Country.where("code = 'TJ'").first
  Country.create(code: 'TJ', name: 'Tajikistan', major: 0) unless country

  country = Country.where("code = 'TK'").first
  Country.create(code: 'TK', name: 'Tokelau', major: 0) unless country

  country = Country.where("code = 'TL'").first
  Country.create(code: 'TL', name: 'Timor-Leste', major: 0) unless country

  country = Country.where("code = 'TM'").first
  Country.create(code: 'TM', name: 'Turkmenistan', major: 0) unless country

  country = Country.where("code = 'TN'").first
  Country.create(code: 'TN', name: 'Tunisia', major: 0) unless country

  country = Country.where("code = 'TO'").first
  Country.create(code: 'TO', name: 'Tonga', major: 0) unless country

  country = Country.where("code = 'TR'").first
  Country.create(code: 'TR', name: 'Turkey', major: 0) unless country

  country = Country.where("code = 'TT'").first
  unless country
    Country.create(code: 'TT', name: 'Trinidad and Tobago', major: 0)
  end

  country = Country.where("code = 'TV'").first
  Country.create(code: 'TV', name: 'Tuvalu', major: 0) unless country

  country = Country.where("code = 'TW'").first
  Country.create(code: 'TW', name: 'Taiwan', major: 0) unless country

  country = Country.where("code = 'TZ'").first
  Country.create(code: 'TZ', name: 'Tanzania', major: 0) unless country

  country = Country.where("code = 'UA'").first
  Country.create(code: 'UA', name: 'Ukraine', major: 0) unless country

  country = Country.where("code = 'UG'").first
  Country.create(code: 'UG', name: 'Uganda', major: 0) unless country

  country = Country.where("code = 'UM'").first
  unless country
    Country.create(code: 'UM', name: 'United States Minor Outlying Islands', major: 0)
  end

  country = Country.where("code = 'US'").first
  unless country
    Country.create(code: 'US', name: 'United States of America', major: 1)
  end

  country = Country.where("code = 'UY'").first
  Country.create(code: 'UY', name: 'Uruguay', major: 0) unless country

  country = Country.where("code = 'UZ'").first
  Country.create(code: 'UZ', name: 'Uzbekistan', major: 0) unless country

  country = Country.where("code = 'VA'").first
  Country.create(code: 'VA', name: 'Holy See', major: 0) unless country

  country = Country.where("code = 'VC'").first
  unless country
    Country.create(code: 'VC', name: 'St. Vincent and the Grenadines', major: 0)
  end

  country = Country.where("code = 'VE'").first
  Country.create(code: 'VE', name: 'Venezuela', major: 0) unless country

  country = Country.where("code = 'VG'").first
  unless country
    Country.create(code: 'VG', name: 'British Virgin Islands', major: 0)
  end

  country = Country.where("code = 'VI'").first
  Country.create(code: 'VI', name: 'US Virgin Islands', major: 0) unless country

  country = Country.where("code = 'VN'").first
  Country.create(code: 'VN', name: 'Viet Nam', major: 0) unless country

  country = Country.where("code = 'VU'").first
  Country.create(code: 'VU', name: 'Vanuatu', major: 0) unless country

  country = Country.where("code = 'WF'").first
  unless country
    Country.create(code: 'WF', name: 'Wallis and Futuna Islands', major: 0)
  end

  country = Country.where("code = 'WS'").first
  Country.create(code: 'WS', name: 'Samoa', major: 0) unless country

  country = Country.where("code = 'YE'").first
  Country.create(code: 'YE', name: 'Yemen', major: 0) unless country

  country = Country.where("code = 'YT'").first
  Country.create(code: 'YT', name: 'Mayotte', major: 0) unless country

  country = Country.where("code = 'ZA'").first
  Country.create(code: 'ZA', name: 'South Africa', major: 0) unless country

  country = Country.where("code = 'ZM'").first
  Country.create(code: 'ZM', name: 'Zambia', major: 0) unless country

  country = Country.where("code = 'ZW'").first
  Country.create(code: 'ZW', name: 'Zimbabwe', major: 0) unless country

end

def self.down
end
