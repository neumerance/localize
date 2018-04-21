require 'spec_helper'
require 'rails_helper'
require 'support/utils_helper'

describe ManagedWorksController, type: :controller do
  include ActionDispatch::TestProcess
  include UtilsHelper
  render_views

  let!(:client) { FactoryGirl.create(:client) }
  let!(:translator) { FactoryGirl.create(:translator) }
  let!(:useraccount) { FactoryGirl.create(:user_account, owner_id: client.id, type: 'UserAccount', balance: 847.08, currency_id: 1) }
  let!(:text_resource) { FactoryGirl.create(:text_resource, client: client, language_id: 1) }
  let!(:resource_string) { FactoryGirl.create(:resource_string, text_resource: text_resource) }
  let!(:string_translation) { FactoryGirl.create(:string_translation, resource_string: resource_string, language_id: 2, status: 3) }
  let!(:resource_language) { FactoryGirl.create(:resource_language, text_resource: text_resource, language_id: 2) }
  let!(:resource_chat) { FactoryGirl.create(:resource_chat, translator: translator, resource_language: resource_language) }
  let!(:managed_work) do
    FactoryGirl.create(:managed_work, owner_id: resource_language.id, owner_type: 'ResourceLanguage', from_language_id: 1,
                                      to_language_id: 2, client_id: client.id)
  end

  context '#update_status' do
    before { login_as(client) }

    it 'should set error if missing active' do
      expect_any_instance_of(ManagedWorksController).to receive(:set_err)
      xhr :post, :update_status, params: { id: managed_work.id }
    end

    context 'when enabling review' do
      it 'should enable translation_status' do
        managed_work.update_attribute :active, 1
        xhr :post, :update_status, params: { id: managed_work.id, active: 0 }
        expect(managed_work.reload.active).to eq(0)
      end
    end

    context 'when disabling review' do
      it 'should disable translation_status' do
        managed_work.update_attribute :active, 0
        xhr :post, :update_status, params: { id: managed_work.id, active: 1 }
        expect(managed_work.reload.active).to eq(1)
      end
    end

    context 'Software projects' do
      context 'when disabling review' do
        it 'should call #refund_review on ResourceLanguage' do
          expect_any_instance_of(ResourceLanguage).to receive(:refund_review).once
          xhr :post, :update_status, params: { id: managed_work.id, active: 0 }
        end
      end

      context 'when enabling review' do
        it 'should not call #refund_review' do
          expect_any_instance_of(ResourceLanguage).to_not receive(:refund_review)
        end
      end
    end
  end
end
