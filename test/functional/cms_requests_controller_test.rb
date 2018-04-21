require File.dirname(__FILE__) + '/../test_helper'
require 'cms_requests_controller'
require 'minitest/unit'

# Re-raise errors caught by the controller.
class CmsRequestsController
  def rescue_action(e)
    raise e
  end
end

class CmsRequestsControllerTest < ActionController::TestCase
  fixtures :websites, :users, :languages, :user_sessions

  def setup
    @session = user_sessions(:amir)
  end

  def test_should_get_index
    website = websites(:amir_drupal_rpc)
    from_language = languages(:English)
    to_language = languages(:Spanish)

    cms_ids = %w(hello1 hello2 hello1)
    cms_ids.each do |cms_id|
      cms_requests_count = CmsRequest.count

      post(:create, params: {
             session: @session.session_num,
             website_id: website.id,
             format: 'xml',
             orig_language: from_language.name,
             to_language1: to_language.name,
             title: 'what we are translating',
             cms_id: cms_id
           })

      assert_response :success

      assert_equal cms_requests_count + 1, CmsRequest.count

      xml = get_xml_tree(@response.body)
      # puts xml

      assert_element_attribute('Upload created', xml.root.elements['result'], 'message')
      cms_request_id = get_element_attribute(xml.root.elements['result'], 'id').to_i

      cms_request = CmsRequest.find(cms_request_id)
      assert cms_request

      # Required for this cms_request to be returned by CmsRequestsController#cms_id
      cms_request.update!(pending_tas: false)

      assert_equal cms_id, cms_request.cms_id
    end

    # -- see if we find these requests
    ids_and_num = [['hello1', 2], ['hello2', 1], ['hello', 0]]

    ids_and_num.each do |id_and_num|

      cms_id = id_and_num[0]
      cnt = id_and_num[1]

      # puts "looking for #{cms_id} times #{cnt}"

      get :cms_id, params: { session: @session.session_num, website_id: website.id, format: 'xml', cms_id: cms_id }
      assert_response :success

      xml = get_xml_tree(@response.body)
      # puts xml

      cms_requests = assigns(:cms_requests)
      assert_equal cnt, cms_requests.length

      cms_requests.each do |cms_request|
        assert_equal cms_id, cms_request.cms_id
      end

    end

  end
end
