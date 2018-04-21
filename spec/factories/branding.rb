FactoryGirl.define do
  factory :branding, class: Branding do
    owner_type 'WebSupport'
    owner_id 1
    language_id 1
    logo_url 'http://www.onthegosoft.com/images/logo1.gif'
    logo_width 600
    logo_height 150
    home_url 'http://www.onthegosoft.com'
  end
end
