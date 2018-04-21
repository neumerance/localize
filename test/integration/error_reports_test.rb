require "#{File.dirname(__FILE__)}/../test_helper"

class ChangesTrackingTest < ActionDispatch::IntegrationTest
  fixtures :users

  def test_create_report
    # post an incomplete report
    post(url_for(controller: :error_reports, format: :xml),
         report: { body: 'The body of the report',
                   description: 'Something I did',
                   #:prog=>'TA',
                   version: '1.2',
                   os: 'Windows XP',
                   email: 'amir@hotmail.com' })
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute('Error report could not be be created', xml.root.elements['result'], 'message')

    post(url_for(controller: :error_reports, format: :xml),
         report: { body: 'The body of the report',
                   description: 'Something I did',
                   prog: 'TA',
                   version: '1.2',
                   os: 'Windows XP' })

    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute('Error report could not be be created', xml.root.elements['result'], 'message')

    # post a completed report
    post(url_for(controller: :error_reports, format: :xml),
         report: { body: 'The body of the report1',
                   description: 'Something I did',
                   prog: 'TA',
                   version: '1.2',
                   os: 'Windows XP',
                   email: 'amir@hotmail.com' })
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute('Error report created', xml.root.elements['result'], 'message')
    report_id = get_element_attribute(xml.root.elements['result'], 'id').to_i

    # post a new report, see that we get a new ID
    post(url_for(controller: :error_reports, format: :xml),
         report: { body: 'The body of the report2',
                   description: 'Something I did',
                   prog: 'TA',
                   version: '1.2',
                   os: 'Windows XP',
                   email: 'amir@hotmail.com' })
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute('Error report created', xml.root.elements['result'], 'message')
    assert_not_equal report_id, get_element_attribute(xml.root.elements['result'], 'id').to_i

    # post the same report, see that we get the same ID
    post(url_for(controller: :error_reports, format: :xml),
         report: { body: 'The body of the report1',
                   description: 'Something I did',
                   prog: 'TA',
                   version: '1.2',
                   os: 'Windows XP',
                   email: 'amir@hotmail.com' })
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute('Error report exists', xml.root.elements['result'], 'message')
    assert_equal report_id, get_element_attribute(xml.root.elements['result'], 'id').to_i

    # post one without a description
    post(url_for(controller: :error_reports, format: :xml),
         report: { body: 'The body of the report',
                   prog: 'TA',
                   version: '1.2',
                   os: 'Windows XP',
                   email: 'amir@hotmail.com' })
    assert_response :success
    xml = get_xml_tree(@response.body)
    assert_element_attribute('Error report created', xml.root.elements['result'], 'message')

    get(url_for(controller: :error_reports, action: :resolution, id: report_id))
    assert_response :success
    assert assigns['error_report']

    # verify that only a supporter can access the reports
    get(url_for(controller: :error_reports, action: :show, id: report_id))
    assert_response :redirect
    assert_nil assigns['error_report']

    client = users(:admin)
    session = login(client)

    get(url_for(controller: :error_reports, action: :show, id: report_id))
    assert_response :success
    assert assigns['error_report']
  end
end
