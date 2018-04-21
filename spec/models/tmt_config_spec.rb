require 'rails_helper'

RSpec.describe TmtConfig, type: :model do
  describe 'tmt_config_toggle' do
    let!(:website) { FactoryGirl.create(:website) }
    let!(:translator) { FactoryGirl.create(:beta_translator) }
    let!(:cms) { FactoryGirl.create(:cms_request, :with_dependencies) }

    before :each do
      cms.revision.chats.each { |chat| chat.update_attribute(:translator, translator) }
      cms.cms_target_language.update_attribute(:translator, translator)
      cms.revision.revision_languages.last.managed_work.update_attribute(:translator, translator)
    end

    it 'should create the config when not present' do
      if ENABLE_MACHINE_TRANSLATION
        cms.toggle_tmt_config
        expect(cms.tmt_configs.where(translator: translator).first.present?).to be_truthy
      end
    end

    it 'should able to toggle tmt_config.enabled' do
      expect(cms.toggle_tmt_config).to be_truthy if ENABLE_MACHINE_TRANSLATION
    end

  end
end
