FactoryGirl.define do
  factory :user_session, class: UserSession do
    login_time { Time.now }
    session_num { Faker::Crypto.md5 }
  end
end
