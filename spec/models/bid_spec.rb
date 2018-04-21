require 'rails_helper'

describe Bid do
  before(:each) do
    @translator = FactoryGirl.create(:translator)
    @cms_request = FactoryGirl.create_list(:cms_request, 1, :with_dependencies).first
    @cms_request.revision.revision_languages.last.managed_work.update_attribute(:translator, @translator)
    @bid = @cms_request.revision.all_bids.where(won: true).first
    @bid.managed_work.update_attributes(active: MANAGED_WORK_ACTIVE, translation_status: MANAGED_WORK_CREATED)
    FactoryGirl.create(:xliff, cms_request: @cms_request, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff"))
  end

  context '#webta_declare_done' do
    it 'should update job as reviewing when review is enabled and reviewer is assigned' do
      reviewer = FactoryGirl.create(:translator)
      @bid.managed_work.update_attribute(:translator, reviewer)
      expect(@bid.status).to eq(BID_ACCEPTED)
      expect(@bid.managed_work.translation_status).to eq(MANAGED_WORK_CREATED)
      @bid.webta_declare_done(@translator.id, @cms_request)
      @bid.reload
      expect(@bid.status).to eq(BID_DECLARED_DONE)
      expect(@bid.managed_work.translation_status).to eq(MANAGED_WORK_REVIEWING)
    end

    it 'should update job as waiting for reviewer when review is enabled and reviewer is not assigned' do
      @bid.managed_work.update_attribute(:translator, nil)
      expect(@bid.status).to eq(BID_ACCEPTED)
      expect(@bid.managed_work.translation_status).to eq(MANAGED_WORK_CREATED)
      @bid.webta_declare_done(@translator.id, @cms_request)
      @bid.reload
      expect(@bid.status).to eq(BID_DECLARED_DONE)
      expect(@bid.managed_work.translation_status).to eq(MANAGED_WORK_WAITING_FOR_REVIEWER)
    end

    it 'should update job as complete when status was reviewing' do
      @bid.managed_work.update_attributes(translation_status: MANAGED_WORK_REVIEWING)
      @bid.update_attribute(:status, BID_DECLARED_DONE)
      @bid.webta_declare_done(@translator.id, @cms_request)
      @bid.reload
      expect(@bid.status).to eq(BID_COMPLETED)
      expect(@bid.managed_work.translation_status).to eq(MANAGED_WORK_COMPLETE)
    end

    it 'should not update job as completed when it is not called by reviewer' do
      @bid.managed_work.update_attributes(translation_status: MANAGED_WORK_REVIEWING)
      @bid.update_attribute(:status, BID_DECLARED_DONE)
      another_translator = FactoryGirl.create(:translator)
      @bid.managed_work.update_attribute(:translator, another_translator)
      @bid.webta_declare_done(@translator.id, @cms_request)
      @bid.reload
      expect(@bid.status).to eq(BID_DECLARED_DONE)
      expect(@bid.managed_work.translation_status).to eq(MANAGED_WORK_REVIEWING)
    end
  end
end
