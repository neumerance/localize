require 'rails_helper'

describe UserToken do

  context 'creation' do
    let!(:translator) { FactoryGirl.create(:translator) }

    it 'should create with right translator' do
      user_token = UserToken.create_token(translator)
      expect(user_token.translator).to eq(translator)
    end

    it 'should be usable' do
      user_token = UserToken.create_token(translator)
      expect(user_token.usable?).to be_truthy
    end

  end

end
