require 'rails_helper'

RSpec.describe XliffTransUnitMrk, type: :model do
  let!(:client) { FactoryGirl.create(:client) }
  let!(:website) { FactoryGirl.create(:website, client: client) }
  let!(:cms_request) { FactoryGirl.create(:cms_request, website: website) }
  let!(:cms_target_language) { FactoryGirl.create(:cms_target_language, cms_request: cms_request) }

  let!(:language) { FactoryGirl.find_or_create(:english_language) }
  let(:unit) { xliff.parsed_xliff.xliff_trans_units.first }
  let(:mrk) { unit.xliff_trans_unit_mrks.first }

  context do
    let!(:xliff) { FactoryGirl.create(:xliff, cms_request: cms_request, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff")) }

    it 'should have all attributes' do
      expect(xliff.parsed_xliff).not_to be_nil
      expect(xliff.parsed_xliff.xliff_trans_units.size).to eq(6)

      expect(unit.trans_unit_id).to eq('wpml_trans_unit_0_0')
      expect(unit.source_language_id).to eq(1)
      expect(unit.target_language_id).to eq(1)
      expect(unit.top_content).to eq("<trans-unit id=\"wpml_trans_unit_0_0\">\n  ")
      expect(unit.bottom_content).to eq("\n</trans-unit>")
      source = '<source>If you need any help with the WPML plugin configuration, you can go through our <g ctype="x-html-a" id="gid_0" xhtml:href="https://wpml.org/documentation/getting-started-guide/">getting started guide</g> or just ask a question on the <g ctype="x-html-a" id="gid_1" xhtml:class="c3" xhtml:href="https://wpml.org/forums/forum/english-support/">support forum</g>.</source>'
      expect(unit.source.toutf8).to eq(source)

      expect(unit.xliff_trans_unit_mrks.size).to eq 2
      expect(mrk.mrk_type).to eq(0)
      expect(mrk.mrk_id).to eq(0)
      expect(mrk.trans_unit_id).to eq('wpml_trans_unit_0_0')
      expect(mrk.language_id).to eq(1)
      expect(mrk.top_content).to eq('<mrk mid="0" mtype="seg" mstatus="0">')
      expect(mrk.bottom_content).to eq('</mrk>')

      target = 'If you need any help with the WPML plugin configuration, you can go through our <g ctype="x-html-a" id="gid_0" xhtml:href="https://wpml.org/documentation/getting-started-guide/">getting started guide</g> or just ask a question on the <g ctype="x-html-a" id="gid_1" xhtml:class="c3" xhtml:href="https://wpml.org/forums/forum/english-support/">support forum</g>.'
      expect(mrk.content.toutf8).to eq(target)
      expect(mrk.mrk_status).to eq(0)
      expect(mrk.source_id).to be_nil
      expect(mrk.target_id).not_to be_nil

      expect(unit.xliff_trans_unit_mrks.last.mrk_type).to eq(1)
      expect(unit.xliff_trans_unit_mrks.last.mrk_id).to eq(0)
      expect(unit.xliff_trans_unit_mrks.last.trans_unit_id).to eq('wpml_trans_unit_0_0')
      expect(unit.xliff_trans_unit_mrks.last.language_id).to eq(1)
      expect(unit.xliff_trans_unit_mrks.last.top_content).to eq('<mrk mid="0" mtype="seg" mstatus="0">')
      expect(unit.xliff_trans_unit_mrks.last.bottom_content).to eq('</mrk>')

      expect(unit.xliff_trans_unit_mrks.last.mrk_status).to eq(0)
      expect(unit.xliff_trans_unit_mrks.last.source_id).not_to be_nil
      expect(unit.xliff_trans_unit_mrks.last.target_id).to be_nil
    end

    it 'should check the markers' do
      target_content = '<g xmlns="urn:oasis:names:tc:xliff:document:1.2" ctype="x-html-span" id="gid_1" xmlns:xhtml="http://www.w3.org/1999/xhtml" xhtml:class="test"><g ctype="x-html-em" id="gid_2">Jon has a <g ctype="bold" id="gid_3">quite big</g> dog with <g ctype="x-html-em" id="gid_4"><g ctype="italic" id="gid_5">very big</g> ears</g> and <g ctype="bold" id="gid_6">he is</g> hungry</g>.</g>'
      source_content = "\n  <g ctype=\"x-html-span\" id=\"gid_1\" xhtml:class=\"test\"><g ctype=\"x-html-em\" id=\"gid_2\">Jon has a <g ctype=\"bold\" id=\"gid_3\">quite big</g> dog with <g ctype=\"x-html-em\" id=\"gid_4\"><g ctype=\"italic\" id=\"gid_5\">very big</g>ears</g> and <g ctype=\"bold\" id=\"gid_6\">he is</g> hungry</g>.</g>\n"
      source_mrk = FactoryGirl.create(:xliff_trans_unit_mrk, content: source_content,
                                                             mrk_type: XliffTransUnitMrk::MRK_TYPES[:source])
      target_mrk = FactoryGirl.create(:xliff_trans_unit_mrk, source_id: source_mrk.id, content: target_content,
                                                             mrk_type: XliffTransUnitMrk::MRK_TYPES[:target])
      expect(target_mrk.has_all_markers?).to be_truthy
    end

    context 'when invalid tag included' do
      it 'should check the markers' do
        target_content = '<div class="selecnium"></div><g xmlns="urn:oasis:names:tc:xliff:document:1.2" ctype="x-html-span" id="gid_1" xmlns:xhtml="http://www.w3.org/1999/xhtml" xhtml:class="test"><g ctype="x-html-em" id="gid_2">Jon has a <g ctype="bold" id="gid_3">quite big</g> dog with <g ctype="x-html-em" id="gid_4"><g ctype="italic" id="gid_5">very big</g> ears</g> and <g ctype="bold" id="gid_6">he is</g> hungry</g>.</g>'
        source_content = "\n  <g ctype=\"x-html-span\" id=\"gid_1\" xhtml:class=\"test\"><g ctype=\"x-html-em\" id=\"gid_2\">Jon has a <g ctype=\"bold\" id=\"gid_3\">quite big</g> dog with <g ctype=\"x-html-em\" id=\"gid_4\"><g ctype=\"italic\" id=\"gid_5\">very big</g>ears</g> and <g ctype=\"bold\" id=\"gid_6\">he is</g> hungry</g>.</g>\n"
        source_mrk = FactoryGirl.create(:xliff_trans_unit_mrk, content: source_content,
                                                               mrk_type: XliffTransUnitMrk::MRK_TYPES[:source])
        target_mrk = FactoryGirl.create(:xliff_trans_unit_mrk, source_id: source_mrk.id, content: target_content,
                                                               mrk_type: XliffTransUnitMrk::MRK_TYPES[:target])
        expect(target_mrk.has_all_markers?).to be_falsey
      end
    end

    it 'should have proper word counts' do
      expect(mrk.word_count).to eq(27)
      expect(xliff.parsed_xliff.tm_word_count).to eq(85)
      expect(xliff.parsed_xliff.word_count).to eq(85)
    end
  end

  context do
    let(:translated_sentence) { ' Else, more will be in denial.' }

    let!(:translation_memory) do
      FactoryGirl.create(:translation_memory, client: client, language: language, content: translated_sentence,
                                              signature: Digest::MD5.hexdigest(translated_sentence))
    end

    let!(:translated_memory) do
      FactoryGirl.create(:translated_memory, client: client, language: language, translation_memory: translation_memory)
    end

    let!(:xliff_with_translated_memory) do
      FactoryGirl.create(:xliff, cms_request: cms_request,
                                 uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/2.xliff"))
    end

    it 'should not count words that are already exists in translated memory' do
      expect(xliff_with_translated_memory.parsed_xliff.tm_word_count).to eq(85)
      expect(xliff_with_translated_memory.parsed_xliff.word_count).to eq(85)
    end
  end
end
