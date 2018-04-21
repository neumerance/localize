require 'rails_helper'

RSpec.describe CmsTargetLanguage, type: :model do

  describe 'new cms_request' do
    let!(:cms_target_language) { FactoryGirl.create(:cms_target_language) }

    it 'should prevent increasingly update wordcount' do
      cms_target_language.update(word_count: 0)
      expect(cms_target_language.reload.word_count).to eq(0)
      cms_target_language.update(word_count: 1000)
      expect(cms_target_language.reload.word_count).to eq(1000)
      cms_target_language.update(word_count: 5000)
      expect(cms_target_language.reload.word_count).to eq(1000)
      cms_target_language.update(word_count: 100)
      expect(cms_target_language.reload.word_count).to eq(100)
      cms_target_language.update(word_count: 50)
      expect(cms_target_language.reload.word_count).to eq(50)
      cms_target_language.update(word_count: 90)
      expect(cms_target_language.reload.word_count).to eq(50)
      cms_target_language.update(word_count: 0)
      expect(cms_target_language.reload.word_count).to eq(0)
      cms_target_language.update(word_count: 5000)
      expect(cms_target_language.reload.word_count).to eq(5000)
      cms_target_language.update(word_count: 100, status: 0)
      expect(cms_target_language.reload.word_count).to eq(100)
      expect(cms_target_language.reload.status).to eq(0)
      cms_target_language.update(word_count: 500, status: 1)
      expect(cms_target_language.reload.word_count).to eq(100)
      expect(cms_target_language.reload.status).to eq(1)
    end

  end
end
