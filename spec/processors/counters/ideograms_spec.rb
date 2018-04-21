require 'rails_helper'

describe Processors::Counters::Ideograms do
  let(:fixtures_path) { Rails.root.join('spec/fixtures/processors/counters') }
  subject { Processors::Counters::Ideograms.new }

  describe '#count' do

    let(:test_cases) do
      JSON.parse(File.read(fixtures_path.join('ideograms.json')), symbolize_names: true).fetch(:tests)
    end

    it 'counts number of ideograms' do
      test_cases.each do |test_case|
        expect(subject.count(test_case.fetch(:input))).to eq test_case.fetch(:expected_result)
      end
    end
  end
end
