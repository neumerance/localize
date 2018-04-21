FactoryGirl.define do
  factory :support_department, class: SupportDepartment do
    name { Faker::Lorem.words(4).join(' ') }
    description { Faker::Lorem.words(12).join(' ') }

    factory :department_projects do
      id 1
      name 'Projects'
      description 'Creating and managing projects on this website'
    end

    factory :department_ta do
      id 2
      name 'Translation Assistant'
      description 'Help using Translation Assistant software on your PC.'
    end

    factory :department_finance do
      id 3
      name 'Finance'
      description 'Help making payments or getting paid.'
    end

    factory :department_general do
      id 4
      name 'General'
      description 'Contact our administrative staff for general inquiries.'
    end

    factory :department_supporter do
      id 5
      name 'Question by supporter'
      description 'Questions or clarifications by a member of the site staff'
    end

    factory :department_setup do
      id 6
      name 'Help setup project'
      description 'Client needs help setting up a project'
    end

    factory :department_cms do
      id 7
      name 'CMS website support'
      description 'Client needs help with CMS site'
    end

  end
end
