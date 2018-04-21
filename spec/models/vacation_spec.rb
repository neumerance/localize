require 'rails_helper'

RSpec.describe Vacation, type: :model do
  context 'validations' do
    shared_examples 'has_base_validation_error' do
      it 'has validation error' do
        vacation.valid?
        expect(vacation.errors[:base][0]).to be_eql(message)
      end
    end

    context 'beginning time in the past' do
      let(:vacation) { FactoryGirl.build(:vacation, beginning: Time.zone.now - 10.days) }
      let(:message) { 'You cannot create a vacation notice for the past' }

      include_examples 'has_base_validation_error'
    end

    context 'ending time in the past' do
      let(:vacation) { FactoryGirl.build(:vacation, ending: Time.zone.now - 10.days) }
      let(:message) { 'You cannot create a vacation notice for the past' }

      include_examples 'has_base_validation_error'
    end

    context 'time start time later that end time' do
      let(:vacation) { FactoryGirl.build(:vacation, beginning: Time.zone.now + 20.days) }
      let(:message) { 'End time cannot be before the beginning time' }

      include_examples 'has_base_validation_error'

    end

    context 'intervals overlaps' do
      let(:user) { FactoryGirl.create(:user) }
      let!(:vacation_with_overlap) { FactoryGirl.create(:vacation, user: user) }
      let(:vacation) { FactoryGirl.build(:vacation, ending: Time.zone.now + 2.days, user: user) }
      let(:message) { 'Vacations could not overlap' }

      include_examples 'has_base_validation_error'
    end
  end
end
