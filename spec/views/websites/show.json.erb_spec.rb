require 'rails_helper'

describe 'websites/show' do
  fixtures :website_translation_offers
  before(:all) { @template = 'websites/show.json.erb' }

  context 'when parameters are correct' do
    let(:translator_per_language_pair) do
      {
        { from: 'English', to: 'Spanish' } => [website_translation_offers(:amir_wp_en_es)],
        { from: 'English', to: 'German' } => [website_translation_offers(:amir_wp_en_de)]
      }
    end

    before(:each) { assign(:translator_per_language_pair, translator_per_language_pair) }
    it_should_behave_like 'json success'

    describe 'response' do
      before(:each) do
        render template: 'websites/show.json.erb'
        @json_resp = JSON.parse(response.body)
      end

      it('have language pairs') { expect(@json_resp).to include('language_pairs') }
      it('language pairs is a hash') { expect(@json_resp['language_pairs']).to be_kind_of(Array) }
      it('have two language pairs') { expect(@json_resp['language_pairs'].size).to eq(2) }

      it('first source language is english') { expect(@json_resp['language_pairs'].first['source']).to eq('English') }
      it('first target language is spanish') { expect(@json_resp['language_pairs'].first['target']).to match(/^(Spanish|German)$/) }
      it('first translators hash') { expect(@json_resp['language_pairs'].first).to include('translators') }
      it('translators is an array') { expect(@json_resp['language_pairs'].first['translators']).to be_kind_of(Array) }
      it('translators array is empty') { expect(@json_resp['language_pairs'].first['translators'].count).to eq(3) }

      it('second source language is english') { expect(@json_resp['language_pairs'].second['source']).to eq('English') }
      it('second target language is german') { expect(@json_resp['language_pairs'].second['target']).to match(/^(Spanish|German)$/) }
      it('second translators hash') { expect(@json_resp['language_pairs'].second).to include('translators') }
      it('translators is an array') { expect(@json_resp['language_pairs'].second['translators']).to be_kind_of(Array) }
      it('translators array is empty') { expect(@json_resp['language_pairs'].second['translators'].count).to eq(3) }
    end
  end
end
