require 'rails_helper'

describe SiteNotice do
  describe 'validations' do
    it 'should validate presence of active' do
      notice = build(:notice, active: nil)
      notice.valid?
      expect(notice.errors[:active].size).to eq(1)
    end

    it 'should able to create notice with valid values' do
      notice = build(:notice)
      notice.valid?
      expect(notice.errors.full_messages.size).to eq(0)
    end

    it 'should not accept start_time pass the current time' do
      notice = build(:notice, start_time: Time.now - 1.day)
      notice.valid?
      expect(notice.errors[:start_time].size).to eq(1)
    end

    it 'should not accept end_time behind start_time' do
      notice = build(:notice, end_time: Time.now - 7.days)
      notice.valid?
      expect(notice.errors[:end_time].size).to eq(1)
    end

    it 'should validate presence of txt' do
      notice = build(:notice, txt: nil)
      notice.valid?
      expect(notice.errors[:txt].size).to eq(1)
    end

    it 'should validate length of txt' do
      site_notice = build(:notice, txt: Faker::Lorem.words(COMMON_NOTE / 4).join(' '))
      site_notice.valid?
      expect(site_notice.errors[:txt].size).to eq(1)
    end
  end
end
