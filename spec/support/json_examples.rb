shared_examples_for 'invalid params error' do
  it 'set error to invalid params' do
    send(verb, action, params: current_params)
    expect(assigns(:json_code)).to eq(INVALID_PARAMS)
  end
end

shared_examples_for 'json success' do
  it 'is a valid json' do
    render template: @template, layout: 'layouts/application.json'
    json_resp = JSON.parse(response.body)
    expect(json_resp).to include('status')
    expect(json_resp['status']).to include('code')
    expect(json_resp['status']).to include('message')
  end

  it 'code returned is 0' do
    render template: @template, layout: 'layouts/application.json'
    json_resp = JSON.parse(response.body)
    expect(json_resp['status']['code']).to eq(0)
  end
end

shared_examples_for 'json error' do
  it 'is a valid json' do
    render template: @template, layout: 'application.json'
    json_resp = JSON.parse(response.body)
    expect(json_resp).to include('status')
    expect(json_resp['status']).to include('code')
    expect(json_resp['status']).to include('message')
  end

  it 'code returned is not 0' do
    render template: @template, layout: 'application.json'
    json_resp = JSON.parse(response.body)
    expect(json_resp['status']['code']).not_to eq(0)
  end

  it 'code response is empty' do
    render template: @template, layout: 'application.json'
    json_resp = JSON.parse(response.body)
    expect(json_resp['response']).not_to exist
  end
end
