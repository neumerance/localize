require "#{File.dirname(__FILE__)}/../test_helper"

class CommErrorsTest < ActionDispatch::IntegrationTest
  fixtures :users, :languages, :websites, :website_translation_offers, :website_translation_contracts, :cms_requests

  def test_create
    cms_request = cms_requests(:page1)
    website = cms_request.website
    user = website.client

    # mark it as complete, there should be no error requests
    cms_request.update_attributes(pending_tas: 0)
    tm = Time.now + 2.hours
    assert_equal 0, CmsRequest.error_requests.length

    # mark it as pending, this request should be pending now
    cms_request.update_attributes(pending_tas: 1)
    assert_equal 1, CmsRequest.error_requests(tm).length
    assert_equal cms_request, CmsRequest.error_requests(tm)[0]

    # still no stuck requests
    assert_equal 0, CmsRequest.stuck_requests.length

    # create comm errors
    session = login(user)
    assert_equal 0, cms_request.comm_errors.length
    comm_error = nil

    for idx in (1..3)

      post(url_for(controller: :comm_errors, action: :create, website_id: website.id, cms_request_id: cms_request.id, format: :xml),
           comm_error: { error_code: 13,
                         error_description: 'Something I did',
                         error_report: 'This was the problem' })
      assert_response :success
      xml = get_xml_tree(@response.body)

      assert_element_attribute('Error created OK', xml.root.elements['result'], 'message')
      id = get_element_attribute(xml.root.elements['result'], 'id').to_i

      comm_error = CommError.find(id)
      assert comm_error

      assert_equal cms_request, comm_error.cms_request
      assert_equal COMM_ERROR_ACTIVE, comm_error.status

      cms_request.reload
      assert_equal idx, cms_request.comm_errors.length

    end

    assert_equal 1, CmsRequest.stuck_requests.length

    # clear the last error
    put(url_for(controller: :comm_errors, action: :update, website_id: website.id, cms_request_id: cms_request.id, id: comm_error.id, format: :xml),
        comm_error: { status: COMM_ERROR_CLOSED })
    assert_response :success

    comm_error.reload
    assert_equal COMM_ERROR_CLOSED, comm_error.status

    # now, it's no longer stuck
    assert_equal 0, CmsRequest.stuck_requests.length

    logout(session)

  end
end
