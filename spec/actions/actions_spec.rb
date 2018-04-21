require 'rails_helper'

RSpec.describe 'Actions' do
  let!(:client) { FactoryGirl.create(:client) }
  let!(:translator) { FactoryGirl.create(:translator) }
  let!(:website) { FactoryGirl.create(:website, client: client) }
  let!(:cms_request) { FactoryGirl.create(:cms_request, website: website) }
  let!(:cms_target_language) { FactoryGirl.create(:cms_target_language, cms_request: cms_request) }
  let!(:file) { TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/g.xml") }
  let!(:xliff) do
    FactoryGirl.create(:xliff, cms_request: cms_request, uploaded_data: file)
  end

  it 'creates parsed xliff' do
    cms_request.update_attributes(xliff_processed: false)

    CmsActions::Parsing::CreateParsedXliff.new.call(xliff_id: xliff.id)
    tm_count = TranslationMemory.where(client_id: client.id).count

    expect(cms_request.reload.parsed_xliffs.count).to eq 1
    expect(cms_request.xliff_trans_unit_mrks.count).to eq 10
    expect(cms_request.loaded_source_mrks.map(&:mrk_status)).to eq [0, 0, 0, 0, 0]
    expect(cms_request.loaded_target_mrks.map(&:mrk_status)).to eq [0, 0, 0, 0, 0]
    expect(tm_count).to eq 5
  end

  context do
    let(:xta_path) { "#{Rails.root}/spec/fixtures/files/xta/g.xml" }
    let(:xta_file) { TempContent.new(xta_path) }

    let!(:parent_cms_request) do
      cms = FactoryGirl.create(:cms_request,
                               website: website, cms_id: cms_request.cms_id, status: CMS_REQUEST_DONE,
                               language_id: cms_request.language_id)
      cms.update_attributes!(id: cms.id - 1000)
      revision = FactoryGirl.create(:revision, cms_request: cms)
      version = revision.versions.create(user: translator, uploaded_data: xta_file)
      version.set_contents(File.read(xta_path))

      cms
    end

    it 'populates memory' do
      cms_request.base_xliff.update_attributes(translated: true)

      expect(cms_request.parsed_xliffs.count).to eq 1
      expect(cms_request.xliff_trans_unit_mrks.count).to eq 10

      tm_scope = -> { TranslationMemory.where(client_id: client.id) }
      tm_scope.call.delete_all

      TranslationMemoryActions::PopulateTranslatedMemory.new.call(
        cms_request: cms_request
      )

      expect(cms_request.reload.parsed_xliffs.count).to eq 1
      expect(cms_request.xliff_trans_unit_mrks.count).to eq 10
      expect(tm_scope.call.count).to eq 5
    end

    it do
      cms_request.base_xliff.update_attributes(translated: true)
      res = TranslationMemoryActions::PopulateTranslatedMemory.new.call(cms_request: cms_request)

      expect(res[:sentences]).to eq(
        [{ original: 'Test_Update_TA_Tool4',
           translated: 'Test_Update_TA_Tool4_German' },
         { original: 'DRS_Ketagoda created this page today, to test if <g ctype="x-html-strong" id="gid_0"><g ctype="x-html-em" id="gid_1">TA Tool</g> </g>sends the completed translation, back to the WPML.',
           translated: "DRS_Ketagoda hat diese Seite heute erstellt, um zu testen, ob <g ctype=\"x-html-strong\" id=\"gid_0\">\n  <g ctype=\"x-html-em\" id=\"gid_1\">TA Tool</g>\n</g> die fertige Übersetzung zurück an die WPML sendet." },
         { original: 'Fragmented sentences are being translated using TA Tool.',
           translated: 'Fragmentierte Sätze werden mit dem TA Tool übersetzt.' },
         { original: 'Current page is updated, and resent to TA Tool.',
           translated: 'Die aktuelle Seite wird aktualisiert und erneut an TA Tool gesendet.' },
         { original: 'Current page is updated for 2nd time, and resent to TA Tool.',
           translated: 'Die aktuelle Seite wird zum 2 zweiten Mal aktualisiert und erneut an TA Tool gesendet.' }]
      )
      cms_request.xliffs.update_all(translated: false)

      other_cms_request = FactoryGirl.create(:cms_request, website: website)
      other_cms_target_language = FactoryGirl.create(:cms_target_language, cms_request: other_cms_request)
      other_xliff = FactoryGirl.create(:xliff, cms_request: other_cms_request, uploaded_data: file)

      other_cms_request.reload

      expect(other_cms_request.loaded_source_mrks.map(&:mrk_status)).to eq [0, 3, 3, 3, 3]
      expect(other_cms_request.loaded_target_mrks.map(&:mrk_status)).to eq [0, 3, 3, 3, 3]

      expect(other_cms_request.loaded_source_mrks.map(&:content)).to eq [
        'Test_Update_TA_Tool4',
        'DRS_Ketagoda created this page today, to test if <g ctype="x-html-strong" id="gid_0"><g ctype="x-html-em" id="gid_1">TA Tool</g> </g>sends the completed translation, back to the WPML.',
        'Fragmented sentences are being translated using TA Tool.',
        'Current page is updated, and resent to TA Tool.',
        'Current page is updated for 2nd time, and resent to TA Tool.'
      ]
      expect(other_cms_request.loaded_target_mrks.map(&:content)).to eq [
        'Test_Update_TA_Tool4',
        "DRS_Ketagoda hat diese Seite heute erstellt, um zu testen, ob <g ctype=\"x-html-strong\" id=\"gid_0\">\n  <g ctype=\"x-html-em\" id=\"gid_1\">TA Tool</g>\n</g> die fertige Übersetzung zurück an die WPML sendet.",
        'Fragmentierte Sätze werden mit dem TA Tool übersetzt.',
        'Die aktuelle Seite wird aktualisiert und erneut an TA Tool gesendet.',
        'Die aktuelle Seite wird zum 2 zweiten Mal aktualisiert und erneut an TA Tool gesendet.'
      ]
    end
  end

  context do
    let!(:file) { TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/base64.xliff") }

    it 'sends an email to supporters if xliff contains base64 content when a job is created' do
      CmsActions::Notifications::AlertSupportersAboutBase64.new.call(cms_request)
      mail = ActionMailer::Base.deliveries.last
      expect(mail.subject).to match(/CMS job source XLIFF has base64 content/i)
    end

    it 'returns false if the xliff does not contain base64 content' do
      file = TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/4.xliff")
      xliff = FactoryGirl.create(:xliff, cms_request: cms_request, uploaded_data: file)
      notify = -> { CmsActions::Notifications::AlertSupportersAboutBase64.new.call(cms_request) }
      expect(&notify).not_to change(ActionMailer::Base.deliveries, :count)
    end
  end
end
