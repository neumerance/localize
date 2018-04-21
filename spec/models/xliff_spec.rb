require 'rails_helper'

RSpec.describe XliffTransUnitMrk, type: :model do
  describe '#translated?' do
    it 'is translated' do
      expect(Xliff.new.translated?).to be false
    end

    it 'is not translated' do
      expect(Xliff.new(translated: true).translated?).to be true
    end
  end

  it 'should have an attachment' do
    cms = FactoryGirl.create(:cms_request, :with_dependencies)
    xliff = FactoryGirl.create(:xliff, cms_request: cms, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff"))
    expect(xliff.get_contents).to be_a(String)
  end

  it 'should create successfully' do
    cms_count = CmsRequest.count
    xliff_count = Xliff.count
    parsed_xliff_count = ParsedXliff.count
    cms = FactoryGirl.create(:cms_request, :with_dependencies)
    xliff = FactoryGirl.create(:xliff, cms_request: cms, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/bad_utf.xliff"))
    expect(CmsRequest.count).to eq(cms_count + 1)
    expect(Xliff.count).to eq(xliff_count + 1)
    expect(ParsedXliff.count).to eq(parsed_xliff_count + 1)
    cms.base_xliff.parsed_xliff.xliff_trans_units.each do |tu|
      expect(tu.source.blank?).to be_falsey
      tu.xliff_trans_unit_mrks.each do |mrk|
        expect(mrk.content.blank?).to be_falsey
      end
    end
  end
end
