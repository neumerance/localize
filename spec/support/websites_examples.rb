shared_examples_for 'require website id and accesskey' do
  def symbol_for_id
    respond_to?(:use_website_id) && use_website_id ? :website_id : :id
  end

  let(:correct_params) do
    {
      :format => :json,
      :api_version => 1.0,
      symbol_for_id => 1,
      :project_id => 1,
      :accesskey => 'abc123'
    }
  end

  describe 'with incorrect parameters' do
    context 'with incorrect id' do
      it 'return the correct error code' do
        params = correct_params
        params[symbol_for_id] = website.id + 1
        send(verb, action, params: params)
        expect(assigns(:json_code)).to eq(AUTHORIZATION_ERROR)
      end
    end
    context 'with incorrect accesskey' do
      it 'return the correct error code' do
        params = correct_params
        params[:accesskey] = website.accesskey + 'foo'
        send(verb, action, params: params)
        expect(assigns(:json_code)).to eq(AUTHORIZATION_ERROR)
      end
    end
  end

  describe 'with missing parameters' do
    context 'with incorrect id' do
      it 'return the correct error code' do
        params = correct_params
        params.delete(symbol_for_id)
        send(verb, action, params: params)
        expect(assigns(:json_code)).to eq(AUTHORIZATION_ERROR)
      end
    end
    context 'with no accesskey' do
      it 'return the correct error code' do
        params = correct_params
        params.delete(:accesskey)
        send(verb, action, params: params)
        expect(assigns(:json_code)).to eq(INVALID_PARAMS)
      end
    end
  end
end
