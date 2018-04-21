require 'rails_helper'

RSpec.describe Translator, type: :model do
  let(:translator) { create(:translator, capacity: 100) }
  let(:fixtures_path) { Rails.root.join('spec/fixtures') }

  context 'Translator::NotFound' do
    it 'should be able to raise NotFound error' do
      expect { raise Translator::NotFound, 'Translator not found' }.to raise_error(Translator::NotFound)
    end
  end

  context '#web_message_in_progress' do
    context 'when a web message translation is in progress' do
      let!(:web_message) { create(:web_message, translator_id: translator.id, translation_status: TRANSLATION_IN_PROGRESS) }

      it 'it should return the web message' do
        expect(translator.web_message_in_progress).to eq(web_message)
      end
    end

    context 'when no web message translation' do
      it 'it should return the web message' do
        expect(translator.web_message_in_progress).to be_nil
      end
    end

    context '#calculate_and_add_complexity' do
      let(:test_cases) do
        JSON.parse(File.read(fixtures_path.join('job_complexities.json')), symbolize_names: true).fetch(:job_objects)
      end
      it 'should have property complexity calculation' do
        test_cases.each do |jobs|
          jobs = translator.calculate_and_add_complexity!(jobs)
          jobs.each do |job|
            expect(job[:progress_details][:complexity]).to eq(job[:progress_details][:expected_complexity])
          end
        end
      end
    end

    context '#calculate_job_status' do
      let(:test_cases) do
        JSON.parse(File.read(fixtures_path.join('job_status.json')), symbolize_names: true).fetch(:job_objects)
      end
      xit 'should have proper job status' do
        test_cases.each do |jobs|
          jobs.each do |job|
            job[:deadline] = (Time.now + job[:deadline].to_i.days).to_i
          end
          jobs = translator.calculate_job_status!(jobs)
          jobs.each do |job|
            expect(job[:progress_details][:status]).to eq(job[:expected_status])
          end
        end
      end
    end
  end
end
