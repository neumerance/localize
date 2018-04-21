require 'rails_helper'

RSpec.describe ParsedXliff, type: :model do
  let!(:client) { FactoryGirl.create(:client) }
  let!(:website) { FactoryGirl.create(:website, client: client) }
  let!(:cms_request) { FactoryGirl.create(:cms_request, website: website) }
  let!(:cms_target_language) { FactoryGirl.create(:cms_target_language, cms_request: cms_request) }
  let!(:xliff) { FactoryGirl.create(:xliff, cms_request: cms_request, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff")) }

  it 'saves it without errors' do
    cms_request.update_attributes(xliff_processed: false)

    CmsActions::Parsing::CreateParsedXliff.new.call(xliff_id: xliff.id)
    expect(cms_request.reload.parsed_xliffs.count).to eq 1
    expect(cms_request.xliff_trans_unit_mrks.count).to eq 12
  end

  it 'updates xliff and cms_request flags after processing is done' do
    new_cms_request = FactoryGirl.create(:cms_request, xliff_processed: false)
    expect(new_cms_request.xliff_processed).to be_falsey

    new_xliff = FactoryGirl.create(:xliff, cms_request: cms_request, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/3.xliff"))
    new_xliff.reload

    expect(new_xliff.processed).to be_truthy
    expect(new_xliff.cms_request.xliff_processed).to be_truthy
  end

  it 'reconstructs the original xliff' do
    header = /<xliff[^>]+>/
    normalize = lambda do |content|
      content.gsub(/>\s+/, '>').
        gsub(/\s+</, '<').
        gsub(%r{\s\/>}, '/>').
        gsub(header, '<xliff>').
        gsub('></br>', '/>').
        gsub('></external-file>', '/>')
    end
    recreated = normalize.call(xliff.parsed_xliff.recreate_original_xliff)
    original = normalize.call(xliff.get_contents)

    expect(recreated).to eq(original)
  end

  it 'should save corectly in db after spliting' do
    input = File.read("#{Rails.root}/spec/fixtures/files/xliffs/1.xliff")
    parsed = Otgs::Segmenter.parsed_xliff(input).gsub(/\s/, '').gsub(/$/, '').gsub('"mstatus="-2"', '"mstatus="0"')
    new_xliff = FactoryGirl.create(:xliff, cms_request: cms_request, uploaded_data: TempContent.new("#{Rails.root}/spec/fixtures/files/xliffs/1.xliff"))
    from_db = new_xliff.parsed_xliff.full_xliff.gsub(/\s/, '').gsub(/$/, '')
    expect(parsed).to eq(from_db)
  end

  it 'updated recently' do
    px = cms_request.base_xliff.parsed_xliff
    expect(px.updated_recently?).to be_truthy
    expect(px).to receive(:recent_threshold_time) { Time.now + 1.minute }
    expect(px.updated_recently?).to be_falsey
  end
end
