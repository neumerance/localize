require 'rails_helper'

RSpec.describe CmsRequest, type: :model do
  describe 'new cms_request' do
    let!(:website) { FactoryGirl.create(:website) }
    let!(:translator) { FactoryGirl.create(:beta_translator) }
    let!(:cms) { FactoryGirl.create(:cms_request, :with_dependencies) }
    before :each do
      cms.revision.chats.each { |chat| chat.update_attribute(:translator, translator) }
      cms.cms_target_language.update_attribute(:translator, translator)
      cms.revision.revision_languages.last.managed_work.update_attribute(:translator, translator)
    end

    it 'should have default mode and threshold' do
      expect(website.tm_use_mode).to eq(TM_COMPLETE_MATCHES)
      expect(website.tm_use_threshold).to eq(3)
    end

    it do
      FactoryGirl.create(
        :xliff, cms_request: cms, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff")
      )
      expect(cms.base_xliff).to be

      original_xliff = cms.original_xliff_content

      sources = ['If you need any help with the WPML plugin configuration, you can go through our <g ctype="x-html-a" id="gid_0" xhtml:href="https://wpml.org/documentation/getting-started-guide/">getting started guide</g> or just ask a question on the <g ctype="x-html-a" id="gid_1" xhtml:class="c3" xhtml:href="https://wpml.org/forums/forum/english-support/">support forum</g>.', 'John has a big <g ctype="bold" id="gid_0">Horse</g>.', '<g ctype="italic" id="gid_0">Marry</g> needs more fruits, i.e <g ctype="bold" id="gid_1">apples</g>.', '<g ctype="x-html-span" id="gid_0">Siri is a smart A.I. Some people do not like N.A.S.A. but other do.<x ctype="x-html-wpml_separator" id="gid_1"/>Those needs to be convinced.</g> Sun is yellow.', '<g ctype="x-html-span" id="gid_0">Siri is a smart A.I. Some people do not like N.A.S.A. but other do.<x ctype="x-html-wpml_separator" id="gid_1"/>Those needs to be convinced</g>.', 'Else, more will be in denial.']
      expect(cms.build_mrk_pairs.map { |x| x[:source_mrk][:content] }).to eq(sources)

      mrk = cms.loaded_target_mrks.first

      cms.save_webta_progress(
        mrk.xliff_id, id: mrk.id, translated_text: Base64.encode64('translation: ' + mrk.content)
      )

      updated_cms = CmsRequest.find(cms.id)

      targets = ['translation: If you need any help with the WPML plugin configuration, you can go through our <g ctype="x-html-a" id="gid_0" xhtml:href="https://wpml.org/documentation/getting-started-guide/">getting started guide</g> or just ask a question on the <g ctype="x-html-a" id="gid_1" xhtml:class="c3" xhtml:href="https://wpml.org/forums/forum/english-support/">support forum</g>.', 'John has a big <g ctype="bold" id="gid_0">Horse</g>.', '<g ctype="italic" id="gid_0">Marry</g> needs more fruits, i.e <g ctype="bold" id="gid_1">apples</g>.', '<g ctype="x-html-span" id="gid_0">Siri is a smart A.I. Some people do not like N.A.S.A. but other do.<x ctype="x-html-wpml_separator" id="gid_1"/>Those needs to be convinced.</g> Sun is yellow.', '<g ctype="x-html-span" id="gid_0">Siri is a smart A.I. Some people do not like N.A.S.A. but other do.<x ctype="x-html-wpml_separator" id="gid_1"/>Those needs to be convinced</g>.', 'Else, more will be in denial.']
      expect(updated_cms.build_mrk_pairs.map { |x| x[:target_mrk][:content] }).to eq(targets)
      expect(updated_cms.original_xliff_content).to_not eq original_xliff

      f = updated_cms.base_xliff.full_filename
      data = ActionDispatch::Http::UploadedFile.new(tempfile: File.new(f))
      data.content_type = 'text/xml'
      data.original_filename = f

      another_xliff = Xliff.create!(uploaded_data: data)
      updated_cms.xliffs << another_xliff
      updated_cms.save!

      # TODO: implement a mechanism like translation memmory for non-completed mrks
      ParsedXliff.create_parsed_xliff(another_xliff)

      updated_cms = CmsRequest.find(cms.id)

      expect(updated_cms.build_mrk_pairs.size).to eq(sources.size)
      expect(updated_cms.build_mrk_pairs.map { |x| x[:target_mrk][:content] }).to match_array(sources)
      expect(updated_cms.original_xliff_content).to eq original_xliff
    end

    it 'should repair' do
      FactoryGirl.create(
        :xliff, cms_request: cms, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff")
      )
      expect(cms.base_xliff).to be

      original_xliff = cms.original_xliff_content

      sources = ['If you need any help with the WPML plugin configuration, you can go through our <g ctype="x-html-a" id="gid_0" xhtml:href="https://wpml.org/documentation/getting-started-guide/">getting started guide</g> or just ask a question on the <g ctype="x-html-a" id="gid_1" xhtml:class="c3" xhtml:href="https://wpml.org/forums/forum/english-support/">support forum</g>.', 'John has a big <g ctype="bold" id="gid_0">Horse</g>.', '<g ctype="italic" id="gid_0">Marry</g> needs more fruits, i.e <g ctype="bold" id="gid_1">apples</g>.', '<g ctype="x-html-span" id="gid_0">Siri is a smart A.I. Some people do not like N.A.S.A. but other do.<x ctype="x-html-wpml_separator" id="gid_1"/>Those needs to be convinced.</g> Sun is yellow.', '<g ctype="x-html-span" id="gid_0">Siri is a smart A.I. Some people do not like N.A.S.A. but other do.<x ctype="x-html-wpml_separator" id="gid_1"/>Those needs to be convinced</g>.', 'Else, more will be in denial.']

      expect(cms.build_mrk_pairs.map { |x| x[:source_mrk][:content] }).to eq(sources)

      mrk = cms.loaded_target_mrks.first

      cms.save_webta_progress(
        mrk.xliff_id, id: mrk.id, translated_text: Base64.encode64('translation: ' + mrk.content)
      )

      updated_cms = CmsRequest.find(cms.id)

      targets = ['translation: If you need any help with the WPML plugin configuration, you can go through our <g ctype="x-html-a" id="gid_0" xhtml:href="https://wpml.org/documentation/getting-started-guide/">getting started guide</g> or just ask a question on the <g ctype="x-html-a" id="gid_1" xhtml:class="c3" xhtml:href="https://wpml.org/forums/forum/english-support/">support forum</g>.', 'John has a big <g ctype="bold" id="gid_0">Horse</g>.', '<g ctype="italic" id="gid_0">Marry</g> needs more fruits, i.e <g ctype="bold" id="gid_1">apples</g>.', '<g ctype="x-html-span" id="gid_0">Siri is a smart A.I. Some people do not like N.A.S.A. but other do.<x ctype="x-html-wpml_separator" id="gid_1"/>Those needs to be convinced.</g> Sun is yellow.', '<g ctype="x-html-span" id="gid_0">Siri is a smart A.I. Some people do not like N.A.S.A. but other do.<x ctype="x-html-wpml_separator" id="gid_1"/>Those needs to be convinced</g>.', 'Else, more will be in denial.']
      expect(updated_cms.build_mrk_pairs.map { |x| x[:target_mrk][:content] }).to eq(targets)
      expect(updated_cms.original_xliff_content).to_not eq original_xliff
      source_ids = updated_cms.build_mrk_pairs.map { |x| x[:source_mrk][:id] }
      target_ids = updated_cms.build_mrk_pairs.map { |x| x[:target_mrk][:id] }

      # re-parse
      updated_cms.repair!
      updated_cms = CmsRequest.find(cms.id)

      # different ids now
      expect(updated_cms.build_mrk_pairs.map { |x| x[:source_mrk][:id] }).to_not eq(source_ids)
      expect(updated_cms.build_mrk_pairs.map { |x| x[:target_mrk][:id] }).to_not eq(target_ids)

      # content is re-set
      expect(cms.build_mrk_pairs.map { |x| x[:source_mrk][:content] }).to eq(sources)
      expect(cms.build_mrk_pairs.map { |x| x[:target_mrk][:content] }).to eq(sources)
    end

    it 'should create translation memory without any translated memory' do
      # expect(cms.base_xliff).to be_nil
      translation_memories_count = TranslationMemory.count
      translated_memories_count = TranslatedMemory.count
      mrks_count = XliffTransUnitMrk.count
      FactoryGirl.create(:xliff, cms_request: cms, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff"))
      expect(cms.base_xliff).not_to be_nil
      expect(cms.base_xliff.parsed_xliff).not_to be_nil

      expect(cms.base_xliff.parsed_xliff.xliff_trans_units.size).to eq(6)
      expect(cms.base_xliff.parsed_xliff.xliff_trans_units.size).to eq(6)
      new_mrks_count = 0
      cms.base_xliff.parsed_xliff.xliff_trans_units.each do |xtru|
        new_mrks_count += xtru.xliff_trans_unit_mrks.size
      end
      expect(new_mrks_count).to eq(12)
      expect(XliffTransUnitMrk.count).to eq(mrks_count + new_mrks_count)
      expect(TranslationMemory.count).to eq(translation_memories_count + new_mrks_count / 2) # only source mrks have translation memory - half are source mrks and half are target
      expect(TranslatedMemory.count).to eq(translated_memories_count)
    end

    it 'should create translation memory and add translated memories after completion' do
      translation_memories_count = TranslationMemory.count
      translated_memories_count = TranslatedMemory.count
      mrks_count = XliffTransUnitMrk.count
      FactoryGirl.create(:xliff, cms_request: cms, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff"))
      new_mrks_count = 0
      cms.base_xliff.parsed_xliff.xliff_trans_units.each do |xtru|
        new_mrks_count += xtru.xliff_trans_unit_mrks.size
      end
      mrks = XliffTransUnitMrk.where(xliff_id: cms.base_xliff.id, mrk_type: XliffTransUnitMrk::MRK_TYPES[:target])
      expect(mrks.size).to eq(6)

      previusly_completed_mrks_count = XliffTransUnitMrk.translation_completed.count
      mrks.each do |mrk|
        mrk.update_status(XliffTransUnitMrk::MRK_STATUS[:translation_completed])
      end

      # expect(XliffTransUnitMrk.where(xliff_id: cms.base_xliff.id, mrk_status: XliffTransUnitMrk::MRK_STATUS[:translation_completed]).count).to eq(new_mrks_count)

      completed_mrks_count = XliffTransUnitMrk.translation_completed.count - previusly_completed_mrks_count
      expect(completed_mrks_count).to eq(new_mrks_count)

      complete_result = cms.complete_webta(translator)
      expect(complete_result).to eq(code: 200, status: 'OK', message: 'Translation completed')
      expect(XliffTransUnitMrk.count).to eq(mrks_count + new_mrks_count)
      expect(TranslationMemory.count).to eq(translation_memories_count + new_mrks_count / 2) # only source mrks have translation memory - half are source mrks and half are target
      expect(TranslatedMemory.count).to eq(translated_memories_count + new_mrks_count / 2)

      # create a new cms with same xliff and expect to be translated from TM
      client = cms.website.client

      cms_1 = FactoryGirl.create(:cms_request, :with_dependencies)
      cms_1.website.update_attribute(:client_id, client.id)
      cms_1.revision.chats.each { |chat| chat.update_attributes(translator: translator) }
      cms_1.cms_target_language.update_attribute(:translator, translator)
      cms_1.revision.revision_languages.last.managed_work.update_attribute(:translator, translator)
      FactoryGirl.create(:xliff, cms_request: cms_1, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff"))
      expect(cms_1.base_xliff.parsed_xliff.all_mrk_completed?).to be_truthy
      expect(XliffTransUnitMrk.where(xliff_id: cms_1.base_xliff.id).map(&:mrk_status).uniq).to eq([XliffTransUnitMrk::MRK_STATUS[:completed_from_tm]])
    end

    it 'should not complete TM if the client chosed not to' do

      FactoryGirl.create(:xliff, cms_request: cms, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff"))
      mrks = XliffTransUnitMrk.where(xliff_id: cms.base_xliff.id, mrk_type: XliffTransUnitMrk::MRK_TYPES[:target])
      expect(mrks.size).to eq(6)
      mrks.each do |mrk|
        mrk.update_status(XliffTransUnitMrk::MRK_STATUS[:translation_completed])
      end
      cms.complete_webta(translator)

      client = cms.website.client

      cms_1 = FactoryGirl.create(:cms_request, :with_dependencies)
      cms_1.website.update_attributes(client_id: client.id, tm_use_mode: TM_PENDING_MATCHES)
      cms_1.revision.chats.each { |chat| chat.update_attributes(translator: translator) }
      cms_1.cms_target_language.update_attribute(:translator, translator)
      cms_1.revision.revision_languages.last.managed_work.update_attribute(:translator, translator)
      FactoryGirl.create(:xliff, cms_request: cms_1, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff"))
      expect(cms_1.base_xliff.parsed_xliff.all_mrk_completed?).to be_falsey
      expect(XliffTransUnitMrk.where(xliff_id: cms_1.base_xliff.id).map(&:mrk_status).uniq).to eq([XliffTransUnitMrk::MRK_STATUS[:in_progress]])
    end

    it 'should not use TM if it is disabled' do

      FactoryGirl.create(:xliff, cms_request: cms, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff"))
      mrks = XliffTransUnitMrk.where(xliff_id: cms.base_xliff.id, mrk_type: XliffTransUnitMrk::MRK_TYPES[:target])
      expect(mrks.size).to eq(6)
      mrks.each do |mrk|
        mrk.update_status(XliffTransUnitMrk::MRK_STATUS[:translation_completed])
      end
      cms.complete_webta(translator)

      client = cms.website.client

      cms_1 = FactoryGirl.create(:cms_request, :with_dependencies)
      cms_1.website.update_attributes(client_id: client.id, tm_use_mode: TM_IGNORE_MATCHES)
      cms_1.revision.chats.each { |chat| chat.update_attributes(translator: translator) }
      cms_1.cms_target_language.update_attribute(:translator, translator)
      cms_1.revision.revision_languages.last.managed_work.update_attribute(:translator, translator)
      FactoryGirl.create(:xliff, cms_request: cms_1, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff"))
      expect(cms_1.base_xliff.parsed_xliff.all_mrk_completed?).to be_falsey
      expect(XliffTransUnitMrk.where(xliff_id: cms_1.base_xliff.id).map(&:mrk_status).uniq).to eq([XliffTransUnitMrk::MRK_STATUS[:original]])
    end

    it 'should apply only to sentences with minimum number of words' do
      FactoryGirl.create(:xliff, cms_request: cms, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff"))
      mrks = XliffTransUnitMrk.where(xliff_id: cms.base_xliff.id, mrk_type: XliffTransUnitMrk::MRK_TYPES[:target])
      expect(mrks.size).to eq(6)
      mrks.each do |mrk|
        mrk.update_status(XliffTransUnitMrk::MRK_STATUS[:translation_completed])
      end
      cms.complete_webta(translator)

      client = cms.website.client

      cms_1 = FactoryGirl.create(:cms_request, :with_dependencies)
      cms_1.website.update_attributes(client_id: client.id, tm_use_mode: TM_COMPLETE_MATCHES, tm_use_threshold: 10)
      cms_1.revision.chats.each { |chat| chat.update_attributes(translator: translator) }
      cms_1.cms_target_language.update_attribute(:translator, translator)
      cms_1.revision.revision_languages.last.managed_work.update_attribute(:translator, translator)
      FactoryGirl.create(:xliff, cms_request: cms_1, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff"))
      expect(cms_1.base_xliff.parsed_xliff.all_mrk_completed?).to be_falsey

      scope = XliffTransUnitMrk.where(xliff_id: cms_1.base_xliff.id, mrk_type: XliffTransUnitMrk::MRK_TYPES[:target])
      statuses = scope.map(&:mrk_status)

      expect(statuses).to match_array [3, 3, 3, 0, 0, 0]
    end

    it 'should apply tm completed only to sentences with minimum number of words set' do
      FactoryGirl.create(:xliff, cms_request: cms, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff"))
      mrks = XliffTransUnitMrk.where(xliff_id: cms.base_xliff.id, mrk_type: XliffTransUnitMrk::MRK_TYPES[:target])
      expect(mrks.size).to eq(6)
      mrks.each do |mrk|
        mrk.update_status(XliffTransUnitMrk::MRK_STATUS[:translation_completed])
      end
      cms.complete_webta(translator)

      client = cms.website.client

      cms_1 = FactoryGirl.create(:cms_request, :with_dependencies)
      cms_1.website.update_attributes(client_id: client.id, tm_use_mode: TM_COMPLETE_MATCHES, tm_use_threshold: 100)
      cms_1.revision.chats.each { |chat| chat.update_attributes(translator: translator) }
      cms_1.cms_target_language.update_attribute(:translator, translator)
      cms_1.revision.revision_languages.last.managed_work.update_attribute(:translator, translator)
      FactoryGirl.create(:xliff, cms_request: cms_1, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff"))
      expect(cms_1.base_xliff.parsed_xliff.all_mrk_completed?).to be_falsey

      scope = XliffTransUnitMrk.where(xliff_id: cms_1.base_xliff.id, mrk_type: XliffTransUnitMrk::MRK_TYPES[:target])
      statuses = scope.map(&:mrk_status)

      expect(statuses).to eq [XliffTransUnitMrk::MRK_STATUS[:original]] * 6
    end

    # this is not the best place to put this test, but checking the other tests
    # I'm creating it here to be able to identify if something else is required
    # in order to save non utf8 chars
    it 'should be able to create xliff trans unit with non_utf8 chars' do
      FactoryGirl.create(:xliff, cms_request: cms, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/non_utf8.xliff"))
      expect(cms.base_xliff).not_to be_nil
      expect(cms.base_xliff.parsed_xliff).not_to be_nil
      expect(cms.base_xliff.parsed_xliff.xliff_trans_units.size).to eq(6)
      expect(cms.base_xliff.parsed_xliff.xliff_trans_units.first.source).to include('ICanLocalize')
    end
  end

  describe '#cancel_translation' do
    before(:each) do
      tp = double('TranslationProxy')
      allow(tp).to receive(:cancel_translation)
    end

    context 'when cms_request is from translation proxy' do

      it 'does not call the cancel translation method' do
        tp = double('TranslationProxy')
        expect(tp).not_to receive :cancel_translation do
          CmsRequest.new.cancel_translation
        end
      end
    end

    context 'when cms_request is not from translation proxy' do
      before(:each) do
        tp = double('TranslationProxy')
        allow(tp).to receive(:cancel_translation)
      end

      it 'calls the cancel translation method' do
        tp = double('TranslationProxy')
        expect(tp).not_to receive :cancel_translation do
          cms = CmsRequest.new(tp_id: 1).cancel_translation
        end
      end
    end
  end
end
