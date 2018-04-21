require 'rails_helper'

describe Processors::Filters::RemovePunctuationMarks do
  let(:fixtures_path) { Rails.root.join('spec/fixtures/processors/filters') }
  subject { Processors::Filters::RemovePunctuationMarks.new }

  describe '#filter' do

    let(:test_cases) do
      JSON.parse(File.read(fixtures_path.join('remove_punctuation_marks.json')), symbolize_names: true).fetch(:tests)
    end

    it 'removes all punctuation marks from the content' do
      test_cases.each do |test_case|
        expect(subject.filter(test_case.fetch(:input))).to eq test_case.fetch(:expected_result)
      end
    end
  end
end
