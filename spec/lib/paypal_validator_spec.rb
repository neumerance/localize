require 'rails_helper'

describe PaypalValidator do

  context '#validate_ipn' do
    let(:logger) { double(:logger) }
    subject { PaypalValidator.new(logger) }
    before do
      allow(logger).to receive(:info)
      allow(logger).to receive(:error)

      http = double
      allow(Net::HTTP).to receive(:start).and_yield http
      allow(http).to receive(:request).with(an_instance_of(Net::HTTP::Get)).
        and_return(Net::HTTPResponse)
    end

    it 'should return false if param is blank' do
      param = ''
      expect(subject.validate_ipn(param)).to be_falsey
    end

    context 'when not able to validate' do
      subject { PaypalValidator.new(logger).validate_ipn('123') }

      it 'should retry 3 times if response is wrong' do
        expect(Net::HTTP).to receive(:new).exactly(3).times
        expect(subject).to be_falsey
      end

      it 'should return true if response is valid' do
        allow_any_instance_of(Net::HTTPResponse).to receive(:body).and_return('VERIFIED')
        expect(subject).to be_truthy
      end

      it 'should return false after 3 wrong attempts' do
        expect(subject).to be_falsey
      end

      it 'should send mail after 3 failed attemps' do
        expect(InternalMailer).to receive_message_chain(:exception_report, :deliver_now)
        subject
      end
    end

  end

end
