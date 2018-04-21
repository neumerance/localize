require 'spec_helper'
require 'rails_helper'

shared_examples_for 'rest client connection' do
  context "when can't connect to TP" do
    it 'raises TP error' do
      allow(RestClient).to receive(:post) { raise SocketError }
      allow(RestClient).to receive(:put) { raise SocketError }
      expect { TranslationProxy::Notification.send(method, params) }.to raise_error(TranslationProxy::Notification::TPError)
    end
  end

  context 'response is not a valid json' do
    it 'raises TP error' do
      allow(RestClient).to receive(:post) { json_garbage_string }
      allow(RestClient).to receive(:put) { raise SocketError }
      expect { TranslationProxy::Notification.send(method, params) }.to raise_error(TranslationProxy::Notification::TPError)
    end
  end

  context 'response is not formated in the expected json format' do
    json_wrong_formats.each do |json_wrong_format_string|
      it 'raises TP error' do
        allow(RestClient).to receive(:post) { json_wrong_format_string }
        allow(RestClient).to receive(:put) { raise SocketError }
        expect { TranslationProxy::Notification.send(method, params) }.to raise_error(TranslationProxy::Notification::TPError)
      end
    end
  end
end
