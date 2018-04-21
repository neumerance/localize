require 'rails_helper'

RSpec.describe ApplicationHelper, type: :helper do
  describe '#my_error_messages_for' do
    let(:mock_params) { :web_message }
    let(:valid_web_message) { FactoryGirl.build(:web_message) }
    let(:invalid_web_message) { FactoryGirl.build(:web_message, comment: nil) }

    it 'returns nil if no object is found' do
      returned_html = helper.my_error_messages_for(mock_params)
      expect(returned_html).to be_nil
    end

    it 'returns nil if an object without errors is found' do
      @web_message = valid_web_message
      @web_message.valid?
      returned_html = helper.my_error_messages_for(mock_params)
      expect(returned_html).to be_nil
    end

    it 'returns the expected HTML if an object with errors is found' do
      @web_message = invalid_web_message
      @web_message.valid?
      returned_html = helper.my_error_messages_for(mock_params)
      expect(returned_html).to include('Found a problem')
    end
  end
end
