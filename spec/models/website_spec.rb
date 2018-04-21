require 'rails_helper'

describe Website do
  context 'validations' do
    shared_examples 'has_base_validation_error' do
      it 'has validation error' do
        issue.valid?
        expect(issue.errors[field].first).to eq(message)
      end
    end

    context 'presence' do
      %w(name cms_kind).each do |field|
        let(:issue) { build(:website, field.to_sym => nil) }
        let(:message) { 'can\'t be blank' }
        let(:field) { field.to_sym }
        include_examples 'has_base_validation_error'
      end
    end

    context 'valid name length' do
      str = (0...256).map { ('a'..'z').to_a[rand(26)] }.join
      let(:issue) { build(:website, name: str) }
      let(:message) { 'is too long (maximum is 255 characters)' }
      let(:field) { :name }
      include_examples 'has_base_validation_error'
    end

    context 'valid url' do
      let(:issue) { build(:website, url: Faker::Crypto.md5) }
      let(:message) { 'must begin with HTTP:// or HTTPS://' }
      let(:field) { :url }
      include_examples 'has_base_validation_error'
    end

    context 'platform kind must be selected' do
      let(:issue) { build(:website, platform_kind: 0) }
      let(:message) { 'must be selected' }
      let(:field) { :platform_kind }
      include_examples 'has_base_validation_error'
    end

    %w(login password).each do |field|
      context "when platform_kind is #{WEBSITE_WORDPRESS}, #{field} should be required" do
        let(:issue) { build(:website, platform_kind: WEBSITE_WORDPRESS) }
        let(:message) { 'cannot be blank' }
        let(:field) { field.to_sym }
        include_examples 'has_base_validation_error'
      end
    end

    context 'specific urls' do
      let!(:urls) { ['http://cardealer:8888', 'http://muuqftrc.preview.infomaniak.website', 'http://35_wp.localhost', 'http://localhost/wordpress', 'http://vonortzuort.reisen', 'http://192.168.1.117:8888/andrevan'] }

      it 'should pass validation for specific urls' do
        urls.each do |url|
          website = FactoryGirl.build(:website, url: url)
          expect(website.valid?).to be_truthy
        end
      end
    end

  end

  context 'timestamps' do

    it 'should have created_at, updated_at, mcat and mcat on new records' do
      website = create(:website)
      expect(website.created_at).to_not be_nil
      expect(website.updated_at).to_not be_nil
    end

    it 'should not be possible to set created_at to nil' do
      website = create(:website)
      ca = website.created_at
      ua = website.updated_at
      expect(ca).to_not be_nil
      expect(ua).to_not be_nil
      website.created_at = nil
      website.updated_at = nil
      save = website.save
      expect(save).to be_truthy
      website.reload
      expect(website.created_at).to eql(ca)
      expect(website.updated_at).to eql(ua)
    end
  end

  describe 'resignation' do

    let!(:cms_request) { FactoryGirl.create(:cms_request, :with_dependencies) }
    let!(:website) { cms_request.website }
    let!(:translator) { cms_request.translator }
    let!(:reviewer) { FactoryGirl.create(:translator) }
    let!(:website_translation_offer) { cms_request.website.website_translation_offers.first }
    let!(:website_translation_contract) { website_translation_offer.website_translation_contracts.first }
    let!(:managed_work) { website_translation_offer.managed_work }

    context 'on translation jobs' do

      it 'translator should have cms translation job' do
        website_translation_contract.update_attributes(status: TRANSLATION_CONTRACT_ACCEPTED)
        expect(translator.has_cms_jobs(website)).to be_truthy
      end

      it 'translator should not have on going translation job' do
        expect(translator.has_on_going_cms_jobs(website)).to be_falsey
      end

      it 'translator should have on going translation job' do
        cms_request.cms_target_languages.first.update_attributes(status: CMS_TARGET_LANGUAGE_ASSIGNED)
        expect(translator.has_on_going_cms_jobs(cms_request.website)).to be_truthy
      end

      it 'should not able to resign' do
        cms_request.cms_target_languages.first.update_attributes(status: CMS_TARGET_LANGUAGE_ASSIGNED)
        expect { website.resign_from_translating(translator, 'any reason') }.to raise_error 'You are not allowed to resign from this website as you have already started a job on it'
      end

      it 'should able to resign' do
        cms_request.cms_target_languages.first.update_attributes(status: CMS_TARGET_LANGUAGE_CREATED)
        website.resign_from_translating(translator, 'any reason')
        expect(translator.has_cms_jobs(website)).to be_falsey
      end

    end

    context 'on review jobs' do

      it 'translator should have website review job' do
        managed_work.update_attributes(translator: reviewer, translation_status: MANAGED_WORK_REVIEWING)
        expect(reviewer.has_cms_reviews(cms_request.website)).to be_truthy
      end

      it 'should able to resign' do
        managed_work.update_attributes(translator: reviewer, translation_status: MANAGED_WORK_REVIEWING)
        website.resign_from_reviewing(reviewer, 'any reason')
        expect(translator.has_cms_reviews(website)).to be_falsey
      end

    end

  end
end
