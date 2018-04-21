require 'rails_helper'

describe 'User' do

  context 'Password' do
    let(:stranger) { create :user, password: Faker::Internet.password, nickname: Faker::Superhero.name }

    it 'should be able to get password' do
      expect(stranger.get_password.present?).to be true
    end

    it 'should able to verify password is hash' do
      expect(stranger.get_password.to_s.length).to eq(60)
    end
  end

  context 'userstatus' do
    let(:client) { build :user, userstatus: 2, type: 'Client' }

    # validation is disabled for this test
    # it 'should not allow userstatus 2 to client' do
    #   client.valid?
    #   expect(client.errors[:userstatus].first).to eq('invalid user status for client')
    # end

    it 'should not have qualified translator userstatus options' do
      expect(client.get_userstatus_options.map { |x| x[1] }).to_not include(2)
    end
  end

  context 'receive emails' do
    describe 'bounced users' do
      let!(:client) { FactoryGirl.create(:client, bounced: true) }
      let!(:translator) { FactoryGirl.create(:translator, bounced: true) }
      let!(:supporter) { FactoryGirl.create(:supporter, bounced: true) }
      let!(:admin) { FactoryGirl.create(:admin, bounced: true) }

      it 'should not receive email as client' do
        expect(client.can_receive_emails?).to be_falsey
      end

      it 'should not receive email as translator' do
        expect(translator.can_receive_emails?).to be_falsey
      end

      it 'should receive email as supporter' do
        expect(supporter.can_receive_emails?).to be_truthy
      end

      it 'should receive email as admin' do
        expect(admin.can_receive_emails?).to be_truthy
      end

    end
  end

end
