require 'rails_helper'

RSpec.describe 'Prepare CMS' do
  it do
    website = create(:website)
    cms = create(:cms_request, website: website)
    CmsActions::PrepareCmsForWebta.new.call(cms_request: cms)
  end
end
