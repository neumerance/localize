require 'rails_helper'

describe CharConversion do
  subject { Object.new.extend(CharConversion) }

  it 'should have BOM constant in the right order' do
    # as we are doing an each to match the bom, we need to match the BOM in the right order to avoid
    # interpreting UTF32 as UTF16
    expect(CharConversion::BOMS.keys).to eq(['UTF-8', 'UTF-32BE', 'UTF-32LE', 'UTF-16BE', 'UTF-16LE'])
  end

  context '#extract_texts_from_android' do
    it 'should raise Parsers::ParseError if not able to parse' do
      expect do
        subject.extract_texts_from_android '<wrong'
      end.to raise_error(Parsers::ParseError)
    end
  end

  context '#remove_bom' do

    it 'should return same string if no BOM is present' do
      test_string = 'abc'
      expect(subject.remove_bom(test_string)).to eq('abc')
    end

    it 'should remove BOM for UTF-8' do
      test_string = 'abc'
      test_string = "\xEF\xBB\xBF".force_encoding('UTF-8').concat(test_string)
      expect(subject.remove_bom(test_string)).to eq('abc')
    end
    it 'should remove BOM for UTF-16BE' do
      test_string = 'abc'.encode('UTF-16BE', 'UTF-8')
      test_string = "\xFE\xFF".force_encoding('UTF-16BE').concat(test_string)
      expect(subject.remove_bom(test_string)).to eq('abc')
    end
    it 'should remove BOM for UTF-16LE' do
      test_string = 'abc'.encode('UTF-16LE', 'UTF-8')
      test_string = "\xFF\xFE".force_encoding('UTF-16LE').concat(test_string)
      expect(subject.remove_bom(test_string)).to eq('abc')
    end
    it 'should remove BOM for UTF-32BE' do
      test_string = 'abc'.encode('UTF-32BE', 'UTF-8')
      test_string = "\x00\00\xFE\xFF".force_encoding('UTF-32BE').concat(test_string)
      expect(subject.remove_bom(test_string)).to eq('abc')
    end
    it 'should remove BOM for UTF-32LE' do
      test_string = 'abc'.encode('UTF-32LE', 'UTF-8')
      test_string = "\xFF\xFE\x00\x00".force_encoding('UTF-32LE').concat(test_string)
      expect(subject.remove_bom(test_string)).to eq('abc')
    end
  end

  describe '#unencode_string' do
    it 'should not modify a UTF-8 string without BOM' do
      test_string = 'testing string'.force_encoding('UTF-8')
      expect(subject.unencode_string(test_string, 0)).to eq(test_string)
    end

    it 'should call remove_bom' do
      expect(subject).to receive(:remove_bom)
      subject.unencode_string 'abc', 0
    end

    it 'should leave BOM when leave_bom is set as true' do
      test_string = 'abc'
      test_string = "\xEF\xBB\xBF".force_encoding('UTF-8').concat(test_string)
      expect(subject.unencode_string(test_string, 0, true)).to eq(test_string)
    end

    context 'when an error is raised' do
      before { allow(CharDet).to receive(:detect).and_raise 'whops!' }
      after do
        subject.unencode_string('a', 0)
      end
      it 'should return nil' do
        expect(subject.unencode_string('a', 0)).to be_nil
      end
      it 'should call Parsers.logger' do
        expect(Parsers).to receive(:logger)
      end
      it 'should send an email' do
        mailer = double(:mailer)
        expect(InternalMailer).to receive(:exception_report).and_return(mailer)
        expect(mailer).to receive(:deliver_now)
      end
    end

    describe 'UndefinedConversionErrors raised on production' do
      it 'should not raise Encoding::UndefinedConversionError when string contains bytes like \xCE' do
        test_string = "Testing String \xCE \xE2 Things that happen at ICl!"
        result = subject.remove_bom(test_string.dup.force_encoding('US-ASCII'))
        expect(result).to eq(test_string)
      end
    end

    describe 'InvalidByteSequenceError raised on production' do
      let(:test_string) do
        CharConversion::BOMS['UTF-16LE'] + "\xD8 followed by \xAA\xD9 on UTF-16LE \xD8\xAA\xD9".force_encoding('UTF-16LE')
      end

      it 'should not raise Encoding::InvalidByteSequenceError' do
        expect { subject.unencode_string(test_string, 1) }.to_not raise_error
      end
    end
  end

  context '#fix_basic_entity' do
    it 'should replace amperstand to entity' do
      test_string = 'You & I'
      expect(subject.fix_basic_entity(test_string)).to eq('You &amp; I')
    end

    it 'should not replace amperstand with entity for all valid entities' do
      entities = %w(amp lt gt quot apos #323 #2)

      entities.each do |entity|
        test_string = "You &#{entity}; I"
        expect(subject.fix_basic_entity(test_string)).to eq(test_string)
      end
    end

    # numeric
  end

end
