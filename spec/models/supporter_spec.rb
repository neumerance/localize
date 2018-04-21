require 'rails_helper'

RSpec.describe ParsedXliff, type: :model do

  it 'should create a new support, not update the last one' do
    s_count = Supporter.count
    Supporter.new_account('aaa', 'aaa@xxx.yyy', '123456')
    expect(Supporter.count).to eq(s_count + 1)
  end

end
