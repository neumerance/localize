require 'rails_helper'

describe Processors::Filters::DecodeHtmlEntities do
  let(:fixtures_path) { Rails.root.join('spec/fixtures/processors/filters') }
  subject { Processors::Filters::DecodeHtmlEntities.new }

  describe '#decode' do

    let(:test_cases) do
      JSON.parse(File.read(fixtures_path.join('remove_html_entities.json')), symbolize_names: true).fetch(:tests)
    end

    it 'removes all HTML tags from input' do
      test_cases.each do |test_case|
        expect(subject.decode(test_case.fetch(:input))).to eq test_case.fetch(:expected_result)
      end
    end
  end
end
