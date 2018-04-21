require File.dirname(__FILE__) + '/../test_helper'

class ResourceLanguageTest < ActiveSupport::TestCase
  fixtures :resource_languages, :managed_works, :money_accounts, :resource_chats, :text_resources, :resource_strings, :string_translations, :users

  def test_review_enabled?
    resource_language = resource_languages(:started_1)
    assert resource_language.review_enabled?

    resource_language = resource_languages(:started_2)
    assert !resource_language.review_enabled?
  end

  def test_ready_to_begin
    rich = money_accounts(:rich)
    poor = money_accounts(:poor)
    started_1 = resource_languages(:started_1)
    started_2 = resource_languages(:started_2)
    started_3 = resource_languages(:started_3)

    # no money account
    assert !started_1.ready_to_begin?(nil)

    # no selected chat
    assert !started_2.ready_to_begin?(rich)

    # no untraslated words
    assert !started_3.ready_to_begin?(rich)

    # dont have money
    assert !started_1.ready_to_begin?(poor)

    # has money
    assert started_1.ready_to_begin?(rich)
  end

  # TODO: test with unreviewed strings
  def test_count_untraslated_words
    rl = resource_languages(:text_resource_ready_to_start_1)
    assert_equal rl.count_untraslated_words(false), 300
  end

  def test_unfunded_words_pending_review_count
    rl = resource_languages(:text_resource_ready_to_start_1)
    assert_equal 0, rl.unfunded_words_pending_review_count(false)
  end

  def test_review_cost
    rl = resource_languages(:text_resource_ready_to_start_1)
    assert_equal rl.review_cost, 0
  end
end
