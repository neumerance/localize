require 'rails_helper'

describe EmailChecker do
  describe '#connect_to_imap' do
    context 'with a valid IMAP server' do
      it 'returns a Net::IMAP object ' do
        expect(subject.connect_to_imap('imap.gmail.com')).to be_instance_of(Net::IMAP)
      end
    end

    context 'when it is unable to connect' do
      it 'returns nil' do
        allow_any_instance_of(Net::IMAP).to receive(:initialize).and_raise(Errno::ENETUNREACH)
        expect(subject.connect_to_imap('imap.gmail.com')).to be nil
      end
    end
  end
end
