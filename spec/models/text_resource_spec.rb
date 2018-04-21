require 'rails_helper'

describe TextResource do
  describe '#create' do
    it 'should not allow to create project without language' do
      project = build(:text_resource, client_id: 1661, language_id: 0, resource_format_id: 1)
      project.valid?
      expect(project.errors[:language_id].size).to eq(1)
    end

    let!(:project1) { FactoryGirl.create(:text_resource, name: 'ICL Sofware') }
    let(:project2) { FactoryGirl.build(:text_resource, name: 'ICL Sofware') }
    let(:new_name) { 'ICL not validated name' }
    it 'should not allow to create project with same name' do
      project2.valid?
      expect(project2.errors[:name].size).to eq(1)
    end

    it 'should able to update the project without the name being validated for uniqueness' do
      project1.assign_attributes(name: new_name)
      project1.valid?
      expect(project2.errors[:name].size).to eq(0)
    end

  end

  context 'validation' do
    let(:text_resource) { build(:text_resource, description: Faker::Lorem.words(COMMON_NOTE / 4).join(' ')) }

    it "should not allow client body length more than #{COMMON_NOTE}" do
      text_resource.valid?
      expect(text_resource.errors[:description].first).to eq("is too long (maximum is #{COMMON_NOTE} characters)")
    end
  end

  describe '#add_languages' do
    subject { build(:text_resource) }
    let!(:original_count) { subject.languages.count }
    let(:single_language_id) { [Language.first.id] }

    it 'return nil if no resource language is added' do
      expect(subject.add_languages([])).to be_nil
    end
    it 'add one single language added' do
      subject.add_languages single_language_id
      expect(subject.languages.count).to eq(original_count + single_language_id.count)
    end
    it 'add multiple languages' do
      languages_ids = Language.limit(3).pluck :id
      subject.add_languages languages_ids
      expect(subject.languages.count).to eq(original_count + languages_ids.count)
    end

    it 'calls #add_blank_translations' do
      expect(subject).to receive(:add_blank_translations)
      subject.add_languages single_language_id
    end
    it 'calls #update_version_num' do
      expect(subject).to receive(:update_version_num)
      subject.add_languages single_language_id
    end

    context 'ManagedWork' do
      it 'creates a managed work' do
        subject.add_languages(single_language_id)
        expect(subject.resource_languages.last.managed_work).to be_a(ManagedWork)
      end
      it 'has the right attributes' do
        subject.add_languages(single_language_id)
        managed_work = subject.resource_languages.last.managed_work

        expect(managed_work.active).to eq(MANAGED_WORK_ACTIVE)
        expect(managed_work.translation_status).to eq(MANAGED_WORK_CREATED)
        expect(managed_work.from_language_id).to eq(subject.language_id)
        expect(managed_work.to_language_id).to eq(single_language_id.first)
        expect(managed_work.client).to eq(subject.client)
        expect(managed_work.owner).to eq(subject.resource_languages.last)
        expect(managed_work.notified).to eq(0)
      end
    end
  end
end
