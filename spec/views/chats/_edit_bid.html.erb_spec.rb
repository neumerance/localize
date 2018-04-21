require 'rails_helper'

describe 'chats/_edit_bid' do

  helper(ApplicationHelper)

  it 'displays a rounded number with max 2 decimal places' do

    revision = FactoryGirl.create(:revision)
    chat = FactoryGirl.create(:chat, revision: revision)
    bid = FactoryGirl.create(:bid, revision: revision, chat: chat)

    assign(:revision, double(minimum_bid_amount: 12.4634634, word_count: 20, payment_units: 10))
    assign(:bid, bid)
    assign(:chat, double(translator: double(private_translator?: false)))
    assign(:lang_id, 'pt')

    render

    expect(rendered).to include 'The minimum bid amount is $12.46'
  end
end
