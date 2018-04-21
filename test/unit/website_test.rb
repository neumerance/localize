require File.dirname(__FILE__) + '/../test_helper'

class WebsiteTest < ActiveSupport::TestCase

  def create_args
    { name: 'Name', description: 'Description', cms_kind: 'Any' }
  end

  # #create
  def test_create
    assert_difference('Website.count', 1) { Website.create(create_args) }
  end

  def test_need_name
    args = create_args
    args.delete(:name)
    assert_no_difference('Website.count') { Website.create(args) }
  end

  def test_does_not_need_description
    args = create_args
    args.delete(:description)
    assert_difference('Website.count', 1) { Website.create(args) }
  end

  def test_have_an_accesskey_after_created
    website = Website.create(create_args)
    assert !website.accesskey.blank?
  end

  def test_have_a_validated_accesskey
    website = Website.create(create_args)
    assert_equal ACCESSKEY_VALIDATED, website.accesskey_ok
  end

  def test_platform_kind_should_be_drupal_even_for_wp
    website = Website.create(create_args)
    assert_equal WEBSITE_DRUPAL, website.platform_kind
  end

  def test_have_a_client
    website = Website.create(create_args)
    assert website.client
  end

  def test_client_should_be_anonymous
    website = Website.create(create_args)
    assert website.client.anon == 1
  end
end
