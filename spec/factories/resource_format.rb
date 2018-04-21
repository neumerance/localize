FactoryGirl.define do
  factory :resource_format, class: ResourceFormat do
    name 'resource format'
    description 'test'
    encoding 0
    kind 0
    line_break 0
    separator_char '='
  end
end
