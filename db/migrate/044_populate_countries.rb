class PopulateCountries < ActiveRecord::Migration
	def self.up
	 country = Country.where(["code = 'AD'"]).first
	 if not country
	  Country.create(:code => "AD", :name => "Andorra", :major => 0)
	 end

	 country = Country.where(["code = 'AE'"]).first
	 if not country
	  Country.create(:code => "AE", :name => "United Arab Emirates", :major => 0)
	 end

	 country = Country.where(["code = 'AF'"]).first
	 if not country
	  Country.create(:code => "AF", :name => "Afghanistan", :major => 0)
	 end

	 country = Country.where(["code = 'AG'"]).first
	 if not country
	  Country.create(:code => "AG", :name => "Antigua and Barbuda", :major => 0)
	 end

	 country = Country.where(["code = 'AI'"]).first
	 if not country
	  Country.create(:code => "AI", :name => "Anguilla", :major => 0)
	 end

	 country = Country.where(["code = 'AL'"]).first
	 if not country
	  Country.create(:code => "AL", :name => "Albania", :major => 0)
	 end

	 country = Country.where(["code = 'AM'"]).first
	 if not country
	  Country.create(:code => "AM", :name => "Armenia", :major => 0)
	 end

	 country = Country.where(["code = 'AN'"]).first
	 if not country
	  Country.create(:code => "AN", :name => "Netherlands Antilles", :major => 0)
	 end

	 country = Country.where(["code = 'AO'"]).first
	 if not country
	  Country.create(:code => "AO", :name => "Angola", :major => 0)
	 end

	 country = Country.where(["code = 'AQ'"]).first
	 if not country
	  Country.create(:code => "AQ", :name => "Antarctica", :major => 0)
	 end

	 country = Country.where(["code = 'AR'"]).first
	 if not country
	  Country.create(:code => "AR", :name => "Argentina", :major => 0)
	 end

	 country = Country.where(["code = 'AS'"]).first
	 if not country
	  Country.create(:code => "AS", :name => "American Samoa", :major => 0)
	 end

	 country = Country.where(["code = 'AT'"]).first
	 if not country
	  Country.create(:code => "AT", :name => "Austria", :major => 0)
	 end

	 country = Country.where(["code = 'AU'"]).first
	 if not country
	  Country.create(:code => "AU", :name => "Australia", :major => 1)
	 end

	 country = Country.where(["code = 'AW'"]).first
	 if not country
	  Country.create(:code => "AW", :name => "Aruba", :major => 0)
	 end

	 country = Country.where(["code = 'AZ'"]).first
	 if not country
	  Country.create(:code => "AZ", :name => "Azerbaijan", :major => 0)
	 end

	 country = Country.where(["code = 'BA'"]).first
	 if not country
	  Country.create(:code => "BA", :name => "Bosnia and Herzegovina", :major => 0)
	 end

	 country = Country.where(["code = 'BB'"]).first
	 if not country
	  Country.create(:code => "BB", :name => "Barbados", :major => 0)
	 end

	 country = Country.where(["code = 'BD'"]).first
	 if not country
	  Country.create(:code => "BD", :name => "Bangladesh", :major => 0)
	 end

	 country = Country.where(["code = 'BE'"]).first
	 if not country
	  Country.create(:code => "BE", :name => "Belgium", :major => 0)
	 end

	 country = Country.where(["code = 'BF'"]).first
	 if not country
	  Country.create(:code => "BF", :name => "Burkina Faso", :major => 0)
	 end

	 country = Country.where(["code = 'BG'"]).first
	 if not country
	  Country.create(:code => "BG", :name => "Bulgaria", :major => 0)
	 end

	 country = Country.where(["code = 'BH'"]).first
	 if not country
	  Country.create(:code => "BH", :name => "Bahrain", :major => 0)
	 end

	 country = Country.where(["code = 'BI'"]).first
	 if not country
	  Country.create(:code => "BI", :name => "Burundi", :major => 0)
	 end

	 country = Country.where(["code = 'BJ'"]).first
	 if not country
	  Country.create(:code => "BJ", :name => "Benin", :major => 0)
	 end

	 country = Country.where(["code = 'BM'"]).first
	 if not country
	  Country.create(:code => "BM", :name => "Bermuda", :major => 0)
	 end

	 country = Country.where(["code = 'BN'"]).first
	 if not country
	  Country.create(:code => "BN", :name => "Brunei Darussalam", :major => 0)
	 end

	 country = Country.where(["code = 'BO'"]).first
	 if not country
	  Country.create(:code => "BO", :name => "Bolivia", :major => 0)
	 end

	 country = Country.where(["code = 'BR'"]).first
	 if not country
	  Country.create(:code => "BR", :name => "Brazil", :major => 0)
	 end

	 country = Country.where(["code = 'BS'"]).first
	 if not country
	  Country.create(:code => "BS", :name => "Bahamas", :major => 0)
	 end

	 country = Country.where(["code = 'BT'"]).first
	 if not country
	  Country.create(:code => "BT", :name => "Bhutan", :major => 0)
	 end

	 country = Country.where(["code = 'BV'"]).first
	 if not country
	  Country.create(:code => "BV", :name => "Bouvet Island", :major => 0)
	 end

	 country = Country.where(["code = 'BW'"]).first
	 if not country
	  Country.create(:code => "BW", :name => "Botswana", :major => 0)
	 end

	 country = Country.where(["code = 'BY'"]).first
	 if not country
	  Country.create(:code => "BY", :name => "Belarus", :major => 0)
	 end

	 country = Country.where(["code = 'BZ'"]).first
	 if not country
	  Country.create(:code => "BZ", :name => "Belize", :major => 0)
	 end

	 country = Country.where(["code = 'CA'"]).first
	 if not country
	  Country.create(:code => "CA", :name => "Canada", :major => 1)
	 end

	 country = Country.where(["code = 'CC'"]).first
	 if not country
	  Country.create(:code => "CC", :name => "Cocos  Islands", :major => 0)
	 end

	 country = Country.where(["code = 'CD'"]).first
	 if not country
	  Country.create(:code => "CD", :name => "Congo", :major => 0)
	 end

	 country = Country.where(["code = 'CF'"]).first
	 if not country
	  Country.create(:code => "CF", :name => "Central African Republic", :major => 0)
	 end

	 country = Country.where(["code = 'CG'"]).first
	 if not country
	  Country.create(:code => "CG", :name => "Congo", :major => 0)
	 end

	 country = Country.where(["code = 'CH'"]).first
	 if not country
	  Country.create(:code => "CH", :name => "Switzerland", :major => 0)
	 end

	 country = Country.where(["code = 'CI'"]).first
	 if not country
	  Country.create(:code => "CI", :name => "Cote D'Ivoire", :major => 0)
	 end

	 country = Country.where(["code = 'CK'"]).first
	 if not country
	  Country.create(:code => "CK", :name => "Cook Islands", :major => 0)
	 end

	 country = Country.where(["code = 'CL'"]).first
	 if not country
	  Country.create(:code => "CL", :name => "Chile", :major => 0)
	 end

	 country = Country.where(["code = 'CM'"]).first
	 if not country
	  Country.create(:code => "CM", :name => "Cameroon", :major => 0)
	 end

	 country = Country.where(["code = 'CN'"]).first
	 if not country
	  Country.create(:code => "CN", :name => "China", :major => 0)
	 end

	 country = Country.where(["code = 'CO'"]).first
	 if not country
	  Country.create(:code => "CO", :name => "Colombia", :major => 0)
	 end

	 country = Country.where(["code = 'CR'"]).first
	 if not country
	  Country.create(:code => "CR", :name => "Costa Rica", :major => 0)
	 end

	 country = Country.where(["code = 'CS'"]).first
	 if not country
	  Country.create(:code => "CS", :name => "Serbia and Montenegro", :major => 0)
	 end

	 country = Country.where(["code = 'CU'"]).first
	 if not country
	  Country.create(:code => "CU", :name => "Cuba", :major => 0)
	 end

	 country = Country.where(["code = 'CV'"]).first
	 if not country
	  Country.create(:code => "CV", :name => "Cape Verde", :major => 0)
	 end

	 country = Country.where(["code = 'CX'"]).first
	 if not country
	  Country.create(:code => "CX", :name => "Christmas Island", :major => 0)
	 end

	 country = Country.where(["code = 'CY'"]).first
	 if not country
	  Country.create(:code => "CY", :name => "Cyprus", :major => 0)
	 end

	 country = Country.where(["code = 'CZ'"]).first
	 if not country
	  Country.create(:code => "CZ", :name => "Czech Republic", :major => 0)
	 end

	 country = Country.where(["code = 'DE'"]).first
	 if not country
	  Country.create(:code => "DE", :name => "Germany", :major => 1)
	 end

	 country = Country.where(["code = 'DJ'"]).first
	 if not country
	  Country.create(:code => "DJ", :name => "Djibouti", :major => 0)
	 end

	 country = Country.where(["code = 'DK'"]).first
	 if not country
	  Country.create(:code => "DK", :name => "Denmark", :major => 0)
	 end

	 country = Country.where(["code = 'DM'"]).first
	 if not country
	  Country.create(:code => "DM", :name => "Dominica", :major => 0)
	 end

	 country = Country.where(["code = 'DO'"]).first
	 if not country
	  Country.create(:code => "DO", :name => "Dominican Republic", :major => 0)
	 end

	 country = Country.where(["code = 'DZ'"]).first
	 if not country
	  Country.create(:code => "DZ", :name => "Algeria", :major => 0)
	 end

	 country = Country.where(["code = 'EC'"]).first
	 if not country
	  Country.create(:code => "EC", :name => "Ecuador", :major => 0)
	 end

	 country = Country.where(["code = 'EE'"]).first
	 if not country
	  Country.create(:code => "EE", :name => "Estonia", :major => 0)
	 end

	 country = Country.where(["code = 'EG'"]).first
	 if not country
	  Country.create(:code => "EG", :name => "Egypt", :major => 0)
	 end

	 country = Country.where(["code = 'EH'"]).first
	 if not country
	  Country.create(:code => "EH", :name => "Western Sahara", :major => 0)
	 end

	 country = Country.where(["code = 'ER'"]).first
	 if not country
	  Country.create(:code => "ER", :name => "Eritrea", :major => 0)
	 end

	 country = Country.where(["code = 'ES'"]).first
	 if not country
	  Country.create(:code => "ES", :name => "Spain", :major => 0)
	 end

	 country = Country.where(["code = 'ET'"]).first
	 if not country
	  Country.create(:code => "ET", :name => "Ethiopia", :major => 0)
	 end

	 country = Country.where(["code = 'FI'"]).first
	 if not country
	  Country.create(:code => "FI", :name => "Finland", :major => 0)
	 end

	 country = Country.where(["code = 'FJ'"]).first
	 if not country
	  Country.create(:code => "FJ", :name => "Fiji", :major => 0)
	 end

	 country = Country.where(["code = 'FK'"]).first
	 if not country
	  Country.create(:code => "FK", :name => "Falkland Islands", :major => 0)
	 end

	 country = Country.where(["code = 'FM'"]).first
	 if not country
	  Country.create(:code => "FM", :name => "Micronesia", :major => 0)
	 end

	 country = Country.where(["code = 'FO'"]).first
	 if not country
	  Country.create(:code => "FO", :name => "Faeroe Islands", :major => 0)
	 end

	 country = Country.where(["code = 'FR'"]).first
	 if not country
	  Country.create(:code => "FR", :name => "France", :major => 1)
	 end

	 country = Country.where(["code = 'GA'"]).first
	 if not country
	  Country.create(:code => "GA", :name => "Gabon", :major => 0)
	 end

	 country = Country.where(["code = 'GB'"]).first
	 if not country
	  Country.create(:code => "GB", :name => "United Kingdom", :major => 1)
	 end

	 country = Country.where(["code = 'GD'"]).first
	 if not country
	  Country.create(:code => "GD", :name => "Grenada", :major => 0)
	 end

	 country = Country.where(["code = 'GE'"]).first
	 if not country
	  Country.create(:code => "GE", :name => "Georgia", :major => 0)
	 end

	 country = Country.where(["code = 'GF'"]).first
	 if not country
	  Country.create(:code => "GF", :name => "French Guiana", :major => 0)
	 end

	 country = Country.where(["code = 'GH'"]).first
	 if not country
	  Country.create(:code => "GH", :name => "Ghana", :major => 0)
	 end

	 country = Country.where(["code = 'GI'"]).first
	 if not country
	  Country.create(:code => "GI", :name => "Gibraltar", :major => 0)
	 end

	 country = Country.where(["code = 'GL'"]).first
	 if not country
	  Country.create(:code => "GL", :name => "Greenland", :major => 0)
	 end

	 country = Country.where(["code = 'GM'"]).first
	 if not country
	  Country.create(:code => "GM", :name => "Gambia", :major => 0)
	 end

	 country = Country.where(["code = 'GN'"]).first
	 if not country
	  Country.create(:code => "GN", :name => "Guinea", :major => 0)
	 end

	 country = Country.where(["code = 'GP'"]).first
	 if not country
	  Country.create(:code => "GP", :name => "Guadaloupe", :major => 0)
	 end

	 country = Country.where(["code = 'GQ'"]).first
	 if not country
	  Country.create(:code => "GQ", :name => "Equatorial Guinea", :major => 0)
	 end

	 country = Country.where(["code = 'GR'"]).first
	 if not country
	  Country.create(:code => "GR", :name => "Greece", :major => 0)
	 end

	 country = Country.where(["code = 'GS'"]).first
	 if not country
	  Country.create(:code => "GS", :name => "South Georgia and the South Sandwich Islands", :major => 0)
	 end

	 country = Country.where(["code = 'GT'"]).first
	 if not country
	  Country.create(:code => "GT", :name => "Guatemala", :major => 0)
	 end

	 country = Country.where(["code = 'GU'"]).first
	 if not country
	  Country.create(:code => "GU", :name => "Guam", :major => 0)
	 end

	 country = Country.where(["code = 'GW'"]).first
	 if not country
	  Country.create(:code => "GW", :name => "Guinea-Bissau", :major => 0)
	 end

	 country = Country.where(["code = 'GY'"]).first
	 if not country
	  Country.create(:code => "GY", :name => "Guyana", :major => 0)
	 end

	 country = Country.where(["code = 'HK'"]).first
	 if not country
	  Country.create(:code => "HK", :name => "Hong Kong", :major => 0)
	 end

	 country = Country.where(["code = 'HM'"]).first
	 if not country
	  Country.create(:code => "HM", :name => "Heard and McDonald Islands", :major => 0)
	 end

	 country = Country.where(["code = 'HN'"]).first
	 if not country
	  Country.create(:code => "HN", :name => "Honduras", :major => 0)
	 end

	 country = Country.where(["code = 'HR'"]).first
	 if not country
	  Country.create(:code => "HR", :name => "Hrvatska", :major => 0)
	 end

	 country = Country.where(["code = 'HT'"]).first
	 if not country
	  Country.create(:code => "HT", :name => "Haiti", :major => 0)
	 end

	 country = Country.where(["code = 'HU'"]).first
	 if not country
	  Country.create(:code => "HU", :name => "Hungary", :major => 0)
	 end

	 country = Country.where(["code = 'ID'"]).first
	 if not country
	  Country.create(:code => "ID", :name => "Indonesia", :major => 0)
	 end

	 country = Country.where(["code = 'IE'"]).first
	 if not country
	  Country.create(:code => "IE", :name => "Ireland", :major => 0)
	 end

	 country = Country.where(["code = 'IL'"]).first
	 if not country
	  Country.create(:code => "IL", :name => "Israel", :major => 0)
	 end

	 country = Country.where(["code = 'IN'"]).first
	 if not country
	  Country.create(:code => "IN", :name => "India", :major => 0)
	 end

	 country = Country.where(["code = 'IO'"]).first
	 if not country
	  Country.create(:code => "IO", :name => "British Indian Ocean Territory", :major => 0)
	 end

	 country = Country.where(["code = 'IQ'"]).first
	 if not country
	  Country.create(:code => "IQ", :name => "Iraq", :major => 0)
	 end

	 country = Country.where(["code = 'IR'"]).first
	 if not country
	  Country.create(:code => "IR", :name => "Iran", :major => 0)
	 end

	 country = Country.where(["code = 'IS'"]).first
	 if not country
	  Country.create(:code => "IS", :name => "Iceland", :major => 0)
	 end

	 country = Country.where(["code = 'IT'"]).first
	 if not country
	  Country.create(:code => "IT", :name => "Italy", :major => 0)
	 end

	 country = Country.where(["code = 'JM'"]).first
	 if not country
	  Country.create(:code => "JM", :name => "Jamaica", :major => 0)
	 end

	 country = Country.where(["code = 'JO'"]).first
	 if not country
	  Country.create(:code => "JO", :name => "Jordan", :major => 0)
	 end

	 country = Country.where(["code = 'JP'"]).first
	 if not country
	  Country.create(:code => "JP", :name => "Japan", :major => 0)
	 end

	 country = Country.where(["code = 'KE'"]).first
	 if not country
	  Country.create(:code => "KE", :name => "Kenya", :major => 0)
	 end

	 country = Country.where(["code = 'KG'"]).first
	 if not country
	  Country.create(:code => "KG", :name => "Kyrgyz Republic", :major => 0)
	 end

	 country = Country.where(["code = 'KH'"]).first
	 if not country
	  Country.create(:code => "KH", :name => "Cambodia", :major => 0)
	 end

	 country = Country.where(["code = 'KI'"]).first
	 if not country
	  Country.create(:code => "KI", :name => "Kiribati", :major => 0)
	 end

	 country = Country.where(["code = 'KM'"]).first
	 if not country
	  Country.create(:code => "KM", :name => "Comoros", :major => 0)
	 end

	 country = Country.where(["code = 'KN'"]).first
	 if not country
	  Country.create(:code => "KN", :name => "St. Kitts and Nevis", :major => 0)
	 end

	 country = Country.where(["code = 'KP'"]).first
	 if not country
	  Country.create(:code => "KP", :name => "Korea", :major => 0)
	 end

	 country = Country.where(["code = 'KR'"]).first
	 if not country
	  Country.create(:code => "KR", :name => "Korea", :major => 0)
	 end

	 country = Country.where(["code = 'KW'"]).first
	 if not country
	  Country.create(:code => "KW", :name => "Kuwait", :major => 0)
	 end

	 country = Country.where(["code = 'KY'"]).first
	 if not country
	  Country.create(:code => "KY", :name => "Cayman Islands", :major => 0)
	 end

	 country = Country.where(["code = 'KZ'"]).first
	 if not country
	  Country.create(:code => "KZ", :name => "Kazakhstan", :major => 0)
	 end

	 country = Country.where(["code = 'LA'"]).first
	 if not country
	  Country.create(:code => "LA", :name => "Lao People's Democratic Republic", :major => 0)
	 end

	 country = Country.where(["code = 'LB'"]).first
	 if not country
	  Country.create(:code => "LB", :name => "Lebanon", :major => 0)
	 end

	 country = Country.where(["code = 'LC'"]).first
	 if not country
	  Country.create(:code => "LC", :name => "St. Lucia", :major => 0)
	 end

	 country = Country.where(["code = 'LI'"]).first
	 if not country
	  Country.create(:code => "LI", :name => "Liechtenstein", :major => 0)
	 end

	 country = Country.where(["code = 'LK'"]).first
	 if not country
	  Country.create(:code => "LK", :name => "Sri Lanka", :major => 0)
	 end

	 country = Country.where(["code = 'LR'"]).first
	 if not country
	  Country.create(:code => "LR", :name => "Liberia", :major => 0)
	 end

	 country = Country.where(["code = 'LS'"]).first
	 if not country
	  Country.create(:code => "LS", :name => "Lesotho", :major => 0)
	 end

	 country = Country.where(["code = 'LT'"]).first
	 if not country
	  Country.create(:code => "LT", :name => "Lithuania", :major => 0)
	 end

	 country = Country.where(["code = 'LU'"]).first
	 if not country
	  Country.create(:code => "LU", :name => "Luxembourg", :major => 0)
	 end

	 country = Country.where(["code = 'LV'"]).first
	 if not country
	  Country.create(:code => "LV", :name => "Latvia", :major => 0)
	 end

	 country = Country.where(["code = 'LY'"]).first
	 if not country
	  Country.create(:code => "LY", :name => "Libyan Arab Jamahiriya", :major => 0)
	 end

	 country = Country.where(["code = 'MA'"]).first
	 if not country
	  Country.create(:code => "MA", :name => "Morocco", :major => 0)
	 end

	 country = Country.where(["code = 'MC'"]).first
	 if not country
	  Country.create(:code => "MC", :name => "Monaco", :major => 0)
	 end

	 country = Country.where(["code = 'MD'"]).first
	 if not country
	  Country.create(:code => "MD", :name => "Moldova", :major => 0)
	 end

	 country = Country.where(["code = 'MG'"]).first
	 if not country
	  Country.create(:code => "MG", :name => "Madagascar", :major => 0)
	 end

	 country = Country.where(["code = 'MH'"]).first
	 if not country
	  Country.create(:code => "MH", :name => "Marshall Islands", :major => 0)
	 end

	 country = Country.where(["code = 'MK'"]).first
	 if not country
	  Country.create(:code => "MK", :name => "Macedonia", :major => 0)
	 end

	 country = Country.where(["code = 'ML'"]).first
	 if not country
	  Country.create(:code => "ML", :name => "Mali", :major => 0)
	 end

	 country = Country.where(["code = 'MM'"]).first
	 if not country
	  Country.create(:code => "MM", :name => "Myanmar", :major => 0)
	 end

	 country = Country.where(["code = 'MN'"]).first
	 if not country
	  Country.create(:code => "MN", :name => "Mongolia", :major => 0)
	 end

	 country = Country.where(["code = 'MO'"]).first
	 if not country
	  Country.create(:code => "MO", :name => "Macao", :major => 0)
	 end

	 country = Country.where(["code = 'MP'"]).first
	 if not country
	  Country.create(:code => "MP", :name => "Northern Mariana Islands", :major => 0)
	 end

	 country = Country.where(["code = 'MQ'"]).first
	 if not country
	  Country.create(:code => "MQ", :name => "Martinique", :major => 0)
	 end

	 country = Country.where(["code = 'MR'"]).first
	 if not country
	  Country.create(:code => "MR", :name => "Mauritania", :major => 0)
	 end

	 country = Country.where(["code = 'MS'"]).first
	 if not country
	  Country.create(:code => "MS", :name => "Montserrat", :major => 0)
	 end

	 country = Country.where(["code = 'MT'"]).first
	 if not country
	  Country.create(:code => "MT", :name => "Malta", :major => 0)
	 end

	 country = Country.where(["code = 'MU'"]).first
	 if not country
	  Country.create(:code => "MU", :name => "Mauritius", :major => 0)
	 end

	 country = Country.where(["code = 'MV'"]).first
	 if not country
	  Country.create(:code => "MV", :name => "Maldives", :major => 0)
	 end

	 country = Country.where(["code = 'MW'"]).first
	 if not country
	  Country.create(:code => "MW", :name => "Malawi", :major => 0)
	 end

	 country = Country.where(["code = 'MX'"]).first
	 if not country
	  Country.create(:code => "MX", :name => "Mexico", :major => 0)
	 end

	 country = Country.where(["code = 'MY'"]).first
	 if not country
	  Country.create(:code => "MY", :name => "Malaysia", :major => 0)
	 end

	 country = Country.where(["code = 'MZ'"]).first
	 if not country
	  Country.create(:code => "MZ", :name => "Mozambique", :major => 0)
	 end

	 country = Country.where(["code = 'NA'"]).first
	 if not country
	  Country.create(:code => "NA", :name => "Namibia", :major => 0)
	 end

	 country = Country.where(["code = 'NC'"]).first
	 if not country
	  Country.create(:code => "NC", :name => "New Caledonia", :major => 0)
	 end

	 country = Country.where(["code = 'NE'"]).first
	 if not country
	  Country.create(:code => "NE", :name => "Niger", :major => 0)
	 end

	 country = Country.where(["code = 'NF'"]).first
	 if not country
	  Country.create(:code => "NF", :name => "Norfolk Island", :major => 0)
	 end

	 country = Country.where(["code = 'NG'"]).first
	 if not country
	  Country.create(:code => "NG", :name => "Nigeria", :major => 0)
	 end

	 country = Country.where(["code = 'NI'"]).first
	 if not country
	  Country.create(:code => "NI", :name => "Nicaragua", :major => 0)
	 end

	 country = Country.where(["code = 'NL'"]).first
	 if not country
	  Country.create(:code => "NL", :name => "Netherlands", :major => 0)
	 end

	 country = Country.where(["code = 'NO'"]).first
	 if not country
	  Country.create(:code => "NO", :name => "Norway", :major => 0)
	 end

	 country = Country.where(["code = 'NP'"]).first
	 if not country
	  Country.create(:code => "NP", :name => "Nepal", :major => 0)
	 end

	 country = Country.where(["code = 'NR'"]).first
	 if not country
	  Country.create(:code => "NR", :name => "Nauru", :major => 0)
	 end

	 country = Country.where(["code = 'NU'"]).first
	 if not country
	  Country.create(:code => "NU", :name => "Niue", :major => 0)
	 end

	 country = Country.where(["code = 'NZ'"]).first
	 if not country
	  Country.create(:code => "NZ", :name => "New Zealand", :major => 0)
	 end

	 country = Country.where(["code = 'OM'"]).first
	 if not country
	  Country.create(:code => "OM", :name => "Oman", :major => 0)
	 end

	 country = Country.where(["code = 'PA'"]).first
	 if not country
	  Country.create(:code => "PA", :name => "Panama", :major => 0)
	 end

	 country = Country.where(["code = 'PE'"]).first
	 if not country
	  Country.create(:code => "PE", :name => "Peru", :major => 0)
	 end

	 country = Country.where(["code = 'PF'"]).first
	 if not country
	  Country.create(:code => "PF", :name => "French Polynesia", :major => 0)
	 end

	 country = Country.where(["code = 'PG'"]).first
	 if not country
	  Country.create(:code => "PG", :name => "Papua New Guinea", :major => 0)
	 end

	 country = Country.where(["code = 'PH'"]).first
	 if not country
	  Country.create(:code => "PH", :name => "Philippines", :major => 0)
	 end

	 country = Country.where(["code = 'PK'"]).first
	 if not country
	  Country.create(:code => "PK", :name => "Pakistan", :major => 0)
	 end

	 country = Country.where(["code = 'PL'"]).first
	 if not country
	  Country.create(:code => "PL", :name => "Poland", :major => 0)
	 end

	 country = Country.where(["code = 'PM'"]).first
	 if not country
	  Country.create(:code => "PM", :name => "St. Pierre and Miquelon", :major => 0)
	 end

	 country = Country.where(["code = 'PN'"]).first
	 if not country
	  Country.create(:code => "PN", :name => "Pitcairn Island", :major => 0)
	 end

	 country = Country.where(["code = 'PR'"]).first
	 if not country
	  Country.create(:code => "PR", :name => "Puerto Rico", :major => 0)
	 end

	 country = Country.where(["code = 'PS'"]).first
	 if not country
	  Country.create(:code => "PS", :name => "Palestinian Territory", :major => 0)
	 end

	 country = Country.where(["code = 'PT'"]).first
	 if not country
	  Country.create(:code => "PT", :name => "Portugal", :major => 0)
	 end

	 country = Country.where(["code = 'PW'"]).first
	 if not country
	  Country.create(:code => "PW", :name => "Palau", :major => 0)
	 end

	 country = Country.where(["code = 'PY'"]).first
	 if not country
	  Country.create(:code => "PY", :name => "Paraguay", :major => 0)
	 end

	 country = Country.where(["code = 'QA'"]).first
	 if not country
	  Country.create(:code => "QA", :name => "Qatar", :major => 0)
	 end

	 country = Country.where(["code = 'RE'"]).first
	 if not country
	  Country.create(:code => "RE", :name => "Reunion", :major => 0)
	 end

	 country = Country.where(["code = 'RO'"]).first
	 if not country
	  Country.create(:code => "RO", :name => "Romania", :major => 0)
	 end

	 country = Country.where(["code = 'RU'"]).first
	 if not country
	  Country.create(:code => "RU", :name => "Russian Federation", :major => 0)
	 end

	 country = Country.where(["code = 'RW'"]).first
	 if not country
	  Country.create(:code => "RW", :name => "Rwanda", :major => 0)
	 end

	 country = Country.where(["code = 'SA'"]).first
	 if not country
	  Country.create(:code => "SA", :name => "Saudi Arabia", :major => 0)
	 end

	 country = Country.where(["code = 'SB'"]).first
	 if not country
	  Country.create(:code => "SB", :name => "Solomon Islands", :major => 0)
	 end

	 country = Country.where(["code = 'SC'"]).first
	 if not country
	  Country.create(:code => "SC", :name => "Seychelles", :major => 0)
	 end

	 country = Country.where(["code = 'SD'"]).first
	 if not country
	  Country.create(:code => "SD", :name => "Sudan", :major => 0)
	 end

	 country = Country.where(["code = 'SE'"]).first
	 if not country
	  Country.create(:code => "SE", :name => "Sweden", :major => 0)
	 end

	 country = Country.where(["code = 'SG'"]).first
	 if not country
	  Country.create(:code => "SG", :name => "Singapore", :major => 0)
	 end

	 country = Country.where(["code = 'SH'"]).first
	 if not country
	  Country.create(:code => "SH", :name => "St. Helena", :major => 0)
	 end

	 country = Country.where(["code = 'SI'"]).first
	 if not country
	  Country.create(:code => "SI", :name => "Slovenia", :major => 0)
	 end

	 country = Country.where(["code = 'SJ'"]).first
	 if not country
	  Country.create(:code => "SJ", :name => "Svalbard & Jan Mayen Islands", :major => 0)
	 end

	 country = Country.where(["code = 'SK'"]).first
	 if not country
	  Country.create(:code => "SK", :name => "Slovakia", :major => 0)
	 end

	 country = Country.where(["code = 'SL'"]).first
	 if not country
	  Country.create(:code => "SL", :name => "Sierra Leone", :major => 0)
	 end

	 country = Country.where(["code = 'SM'"]).first
	 if not country
	  Country.create(:code => "SM", :name => "San Marino", :major => 0)
	 end

	 country = Country.where(["code = 'SN'"]).first
	 if not country
	  Country.create(:code => "SN", :name => "Senegal", :major => 0)
	 end

	 country = Country.where(["code = 'SO'"]).first
	 if not country
	  Country.create(:code => "SO", :name => "Somalia", :major => 0)
	 end

	 country = Country.where(["code = 'SR'"]).first
	 if not country
	  Country.create(:code => "SR", :name => "Suriname", :major => 0)
	 end

	 country = Country.where(["code = 'ST'"]).first
	 if not country
	  Country.create(:code => "ST", :name => "Sao Tome and Principe", :major => 0)
	 end

	 country = Country.where(["code = 'SV'"]).first
	 if not country
	  Country.create(:code => "SV", :name => "El Salvador", :major => 0)
	 end

	 country = Country.where(["code = 'SY'"]).first
	 if not country
	  Country.create(:code => "SY", :name => "Syrian Arab Republic", :major => 0)
	 end

	 country = Country.where(["code = 'SZ'"]).first
	 if not country
	  Country.create(:code => "SZ", :name => "Swaziland", :major => 0)
	 end

	 country = Country.where(["code = 'TC'"]).first
	 if not country
	  Country.create(:code => "TC", :name => "Turks and Caicos Islands", :major => 0)
	 end

	 country = Country.where(["code = 'TD'"]).first
	 if not country
	  Country.create(:code => "TD", :name => "Chad", :major => 0)
	 end

	 country = Country.where(["code = 'TF'"]).first
	 if not country
	  Country.create(:code => "TF", :name => "French Southern Territories", :major => 0)
	 end

	 country = Country.where(["code = 'TG'"]).first
	 if not country
	  Country.create(:code => "TG", :name => "Togo", :major => 0)
	 end

	 country = Country.where(["code = 'TH'"]).first
	 if not country
	  Country.create(:code => "TH", :name => "Thailand", :major => 0)
	 end

	 country = Country.where(["code = 'TJ'"]).first
	 if not country
	  Country.create(:code => "TJ", :name => "Tajikistan", :major => 0)
	 end

	 country = Country.where(["code = 'TK'"]).first
	 if not country
	  Country.create(:code => "TK", :name => "Tokelau", :major => 0)
	 end

	 country = Country.where(["code = 'TL'"]).first
	 if not country
	  Country.create(:code => "TL", :name => "Timor-Leste", :major => 0)
	 end

	 country = Country.where(["code = 'TM'"]).first
	 if not country
	  Country.create(:code => "TM", :name => "Turkmenistan", :major => 0)
	 end

	 country = Country.where(["code = 'TN'"]).first
	 if not country
	  Country.create(:code => "TN", :name => "Tunisia", :major => 0)
	 end

	 country = Country.where(["code = 'TO'"]).first
	 if not country
	  Country.create(:code => "TO", :name => "Tonga", :major => 0)
	 end

	 country = Country.where(["code = 'TR'"]).first
	 if not country
	  Country.create(:code => "TR", :name => "Turkey", :major => 0)
	 end

	 country = Country.where(["code = 'TT'"]).first
	 if not country
	  Country.create(:code => "TT", :name => "Trinidad and Tobago", :major => 0)
	 end

	 country = Country.where(["code = 'TV'"]).first
	 if not country
	  Country.create(:code => "TV", :name => "Tuvalu", :major => 0)
	 end

	 country = Country.where(["code = 'TW'"]).first
	 if not country
	  Country.create(:code => "TW", :name => "Taiwan", :major => 0)
	 end

	 country = Country.where(["code = 'TZ'"]).first
	 if not country
	  Country.create(:code => "TZ", :name => "Tanzania", :major => 0)
	 end

	 country = Country.where(["code = 'UA'"]).first
	 if not country
	  Country.create(:code => "UA", :name => "Ukraine", :major => 0)
	 end

	 country = Country.where(["code = 'UG'"]).first
	 if not country
	  Country.create(:code => "UG", :name => "Uganda", :major => 0)
	 end

	 country = Country.where(["code = 'UM'"]).first
	 if not country
	  Country.create(:code => "UM", :name => "United States Minor Outlying Islands", :major => 0)
	 end

	 country = Country.where(["code = 'US'"]).first
	 if not country
	  Country.create(:code => "US", :name => "United States of America", :major => 1)
	 end

	 country = Country.where(["code = 'UY'"]).first
	 if not country
	  Country.create(:code => "UY", :name => "Uruguay", :major => 0)
	 end

	 country = Country.where(["code = 'UZ'"]).first
	 if not country
	  Country.create(:code => "UZ", :name => "Uzbekistan", :major => 0)
	 end

	 country = Country.where(["code = 'VA'"]).first
	 if not country
	  Country.create(:code => "VA", :name => "Holy See", :major => 0)
	 end

	 country = Country.where(["code = 'VC'"]).first
	 if not country
	  Country.create(:code => "VC", :name => "St. Vincent and the Grenadines", :major => 0)
	 end

	 country = Country.where(["code = 'VE'"]).first
	 if not country
	  Country.create(:code => "VE", :name => "Venezuela", :major => 0)
	 end

	 country = Country.where(["code = 'VG'"]).first
	 if not country
	  Country.create(:code => "VG", :name => "British Virgin Islands", :major => 0)
	 end

	 country = Country.where(["code = 'VI'"]).first
	 if not country
	  Country.create(:code => "VI", :name => "US Virgin Islands", :major => 0)
	 end

	 country = Country.where(["code = 'VN'"]).first
	 if not country
	  Country.create(:code => "VN", :name => "Viet Nam", :major => 0)
	 end

	 country = Country.where(["code = 'VU'"]).first
	 if not country
	  Country.create(:code => "VU", :name => "Vanuatu", :major => 0)
	 end

	 country = Country.where(["code = 'WF'"]).first
	 if not country
	  Country.create(:code => "WF", :name => "Wallis and Futuna Islands", :major => 0)
	 end

	 country = Country.where(["code = 'WS'"]).first
	 if not country
	  Country.create(:code => "WS", :name => "Samoa", :major => 0)
	 end

	 country = Country.where(["code = 'YE'"]).first
	 if not country
	  Country.create(:code => "YE", :name => "Yemen", :major => 0)
	 end

	 country = Country.where(["code = 'YT'"]).first
	 if not country
	  Country.create(:code => "YT", :name => "Mayotte", :major => 0)
	 end

	 country = Country.where(["code = 'ZA'"]).first
	 if not country
	  Country.create(:code => "ZA", :name => "South Africa", :major => 0)
	 end

	 country = Country.where(["code = 'ZM'"]).first
	 if not country
	  Country.create(:code => "ZM", :name => "Zambia", :major => 0)
	 end

	 country = Country.where(["code = 'ZW'"]).first
	 if not country
	  Country.create(:code => "ZW", :name => "Zimbabwe", :major => 0)
	 end

	end


	def self.down
	end
end
