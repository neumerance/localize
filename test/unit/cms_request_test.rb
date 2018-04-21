require File.dirname(__FILE__) + '/../test_helper'

class CmsRequestTest < ActiveSupport::TestCase
  fixtures :cms_requests, :websites

  skip def test_list_items
    page = cms_requests(:page1)
    assert_equal 0, page.previous_requests.length
    assert_equal 0, page.following_requests.length

    post = cms_requests(:post2)
    assert_equal 1, post.previous_requests.length
    assert_equal 3, post.following_requests.length

    float = cms_requests(:float2)
    assert_equal 0, float.previous_requests.length
    assert_equal 0, float.following_requests.length

    lista1 = cms_requests(:lista1)
    lista = cms_requests(:lista4)
    assert_equal 3, lista.previous_requests.length
    assert_equal 1, lista.following_requests.length

    CmsRequest.record_timestamps = false

    # the first item becomes old, but still blocking
    lista1.update_attributes(updated_at: (Time.now - 2 * DAY_IN_SECONDS))
    assert_equal 3, lista.previous_requests.length
    assert_equal 1, lista.following_requests.length

    # the first item becomes too old and it's not blocking any more
    update_tm = (Time.now - 4 * DAY_IN_SECONDS)
    lista1.update_attributes(updated_at: update_tm)
    lista1.reload
    assert_equal update_tm.to_i, lista1.updated_at.to_i
    assert_equal 2, lista.previous_requests.length
    assert_equal 1, lista.following_requests.length
  end
end
