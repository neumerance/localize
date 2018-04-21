require 'rails_helper'

describe Api do
  include ActionDispatch::TestProcess
  # fixtures :all

  describe '#quote' do
    context 'unsupported file' do
      it 'fail' do
        answer = Api.new.quote(fixture_file_upload('files/empty.foobar'))
        expect(answer[:status]).to eq('fail')
      end
      it 'have an disclaimer message' do
        answer = Api.new.quote(fixture_file_upload('files/empty.foobar'))
        expect(answer[:message]).to eq("Sorry, we don't know how to read your file.")
      end
    end

    context 'Office document files' do
      before(:each) do
        allow(Docsplit).to receive(:extract_text)
      end

      ZippedFile.extensions.each do |ext|
        expected_n_words = ZippedFile.spreadsheet_extension?(ext) ? 5 : 2

        expected_quote = expected_n_words * BigDecimal('0.09')
        it 'count the number of words' do
          allow(File).to receive(:read) { 'test ' * expected_n_words }
          answer = Api.new.quote(fixture_file_upload("files/bidding/test#{ext}"))
          expect(answer[:wordCount]).to eq(expected_n_words)
        end
        it "quote for a #{ext}" do
          allow(File).to receive(:read) { 'test ' * expected_n_words }
          answer = Api.new.quote(fixture_file_upload("files/bidding/test#{ext}"))
          expect(answer[:quote]).to eq(expected_quote)
        end
        it 'be successful' do
          allow(File).to receive(:read) { 'test ' * expected_n_words }
          answer = Api.new.quote(fixture_file_upload("files/bidding/test#{ext}"))
          expect(answer[:status]).to eq('success')
        end
        it 'detect the file type' do
          allow(File).to receive(:read) { 'test ' * expected_n_words }
          answer = Api.new.quote(fixture_file_upload("files/bidding/test#{ext}"))
          expect(answer[:fileType]).to eq(ZippedFile.format_name_for(ext))
        end
      end
    end

    context '.string file' do
      it 'count the number of words' do
        answer = Api.new.quote(fixture_file_upload('files/software/test.strings'))
        expect(answer[:wordCount]).to eq(2)
      end
      it 'quote for a txt' do
        answer = Api.new.quote(fixture_file_upload('files/software/test.strings'))
        expect(answer[:quote]).to eq(0.18)
      end
      it 'be successful' do
        answer = Api.new.quote(fixture_file_upload('files/software/test.strings'))
        expect(answer[:status]).to eq('success')
      end
      it 'detect the file type' do
        answer = Api.new.quote(fixture_file_upload('files/software/test.strings'))
        expect(answer[:fileType]).to eq('iPhone')
      end
    end
  end
end
