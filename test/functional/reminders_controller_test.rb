require File.dirname(__FILE__) + '/../test_helper'
require 'reminders_controller'

# Re-raise errors caught by the controller.
class RemindersController
  def rescue_action(e)
    raise e
  end
end

class RemindersControllerTest < ActionController::TestCase
  fixtures :users, :invoices, :websites, :reminders

  def test_index

    user = users(:amir)
    assert_equal 2, user.reminders.length

    website = websites(:amir_drupal_rpc)

    accesskey = website.accesskey
    wid = website.id

    get(:index, wid: wid, accesskey: accesskey, format: 'xml')
    assert_response :success

    r = user.reminders[0]
    post(:destroy, _method: 'DELETE', wid: wid, accesskey: accesskey, id: r.id, format: 'xml')
    assert_response :success

    xml = get_xml_tree(@response.body)
    assert_element_text('Reminder deleted', xml.root.elements['result'])

    user.reload
    assert_equal 1, user.reminders.length

  end

end
