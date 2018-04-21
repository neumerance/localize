require 'rails_helper'

RSpec.describe TranslationMemory, type: :model do
  let(:command) { TranslationMemoryActions::CreateTranslationMemory.new }
  let!(:client) { FactoryGirl.create(:client) }
  let!(:language) { FactoryGirl.create(:language) }
  let!(:translation_memory) do
    FactoryGirl.create(:translation_memory, content: 'xxx', language: language,
                                            signature: IclHelpers::Common.calculate_signature('xxx'), client: client)
  end

  it 'should create a new one' do
    tms_count = TranslationMemory.count
    content = 'abc'
    command.find_or_create_tm(content, client, language, 5)
    expect(TranslationMemory.count).to eq(tms_count + 1)
  end

  it 'should find an existing one' do
    tms_count = TranslationMemory.count
    content = 'xxx'
    command.find_or_create_tm(content, client, language, 5)
    expect(TranslationMemory.count).to eq(tms_count)
  end
end
