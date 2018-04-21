require 'rails_helper'

describe Processors::WordCounter do
  let(:fixtures_path) { Rails.root.join('spec/fixtures/processors') }

  describe '.count' do

    let(:test_cases) do
      JSON.parse(File.read(fixtures_path.join('word_counter.json')), symbolize_names: true).fetch(:tests)
    end

    it 'counts words' do
      test_cases.each do |test_case|
        subject = Processors::WordCounter.count(test_case.fetch(:sentence), test_case.fetch(:count_method), test_case.fetch(:ratio))
        expect(subject).to eq test_case.fetch(:expected_result)
      end
    end
  end
end
