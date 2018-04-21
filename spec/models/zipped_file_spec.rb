require 'spec_helper'
require 'rails_helper'

describe ZippedFile do
  include ActionDispatch::TestProcess
  # libreoofice has to be installed. it is crashing with openoffice

  describe '#text' do
    before(:each) do
      allow(double('Docsplit')).to receive(:extract_text)
    end

    it 'extract text from TXT' do
      allow(double('File')).to receive(:read) { 'text text' }
      file = ZippedFile.new(uploaded_data: fixture_file_upload('files/bidding/test.txt'))
      expect(file.text.split.size).to eq(2)
    end

    it 'extract text from PDF' do
      allow(double('File')).to receive(:read) { 'text text' }
      file = ZippedFile.new(uploaded_data: fixture_file_upload('files/bidding/test.pdf'))
      expect(file.text.split.size).to eq(2)
    end

    it 'extract text from RTF' do
      allow(double('File')).to receive(:read) { 'text text' }
      file = ZippedFile.new(uploaded_data: fixture_file_upload('files/bidding/test.rtf'))
      expect(file.text.split.size).to eq(2)
    end

    it 'extract text from DOC' do
      allow(double('File')).to receive(:read) { 'text text' }
      file = ZippedFile.new(uploaded_data: fixture_file_upload('files/bidding/test.doc'))
      expect(file.text.split.size).to eq(2)
    end

    it 'extract text from DOCX' do
      allow(double('File')).to receive(:read) { 'text text' }
      file = ZippedFile.new(uploaded_data: fixture_file_upload('files/bidding/test.docx'))
      expect(file.text.split.size).to eq(2)
    end

    it 'extract text from ODT' do
      allow(double('File')).to receive(:read) { 'text text' }
      file = ZippedFile.new(uploaded_data: fixture_file_upload('files/bidding/test.odt'))
      expect(file.text.split.size).to eq(2)
    end

    it 'extract text from CSV' do
      allow(double('File')).to receive(:read) { 'text text text text text' }
      file = ZippedFile.new(uploaded_data: fixture_file_upload('files/bidding/test.csv'))
      expect(file.text.split.size).to eq(2)
    end

    it 'extract text from XLS' do
      allow(double('File')).to receive(:read) { 'text text text text text' }
      file = ZippedFile.new(uploaded_data: fixture_file_upload('files/bidding/test.xls'))
      expect(file.text.split.size).to eq(5)
    end

    it 'extract text from XLSX' do
      allow(double('File')).to receive(:read) { 'text text text text text' }
      file = ZippedFile.new(uploaded_data: fixture_file_upload('files/bidding/test.xlsx'))
      expect(file.text.split.size).to eq(5)
    end

    it 'extract text from ODS' do
      allow(double('File')).to receive(:read) { 'text text text text text' }
      file = ZippedFile.new(uploaded_data: fixture_file_upload('files/bidding/test.ods'))
      expect(file.text.split.size).to eq(5)
    end
  end

  describe '#get_contents' do
    context 'given a valid gzip file' do
      it 'extracts its contents' do
        zipped_file = ZippedFile.create!(
          uploaded_data: fixture_file_upload('files/test.xliff.gz',
                                             'application/x-gzip')
        )
        expect(zipped_file.get_contents).to include('xliff version')
      end
    end

    context 'given an invalid gzip file' do
      it 'returns nil (does not raise an exception)' do
        zipped_file = ZippedFile.create!(
          uploaded_data: fixture_file_upload('files/bidding/test.txt',
                                             'text/plain')
        )
        expect(zipped_file.get_contents).to be_nil
      end
    end
  end
end
