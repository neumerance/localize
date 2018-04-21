require File.dirname(__FILE__) + '/../test_helper'

class TextResourcesTest < ActiveSupport::TestCase

  fixtures :text_resources, :resource_chats, :resource_languages, :languages, :resource_strings, :string_translations, :resource_stats
  def test_validate
    assert true
  end

  def test_untranslated_strings
    tr = text_resources(:amir_ready_to_start)
    assert_equal tr.untranslated_strings(languages(:Spanish)).size, 100
  end

  def test_delete_old_resource_status
    text_resource = text_resources(:amir_started)
    initial_stats_size = text_resource.resource_stats.size

    # Cleanup all
    text_resource.delete_old_resource_stats(nil)
    assert_equal initial_stats_size - 1, text_resource.resource_stats.size

    # Cleanup for resource language
    resource_language = text_resource.resource_languages.find(5)
    text_resource.delete_old_resource_stats(resource_language)
    assert_equal initial_stats_size - 2, text_resource.resource_stats.size
  end

  def test_get_count_from_resource_stats
    text_resource = text_resources(:amir_started)

    name = 'name'
    stats = text_resource.get_count_from_resource_stats(name, nil)
    assert_equal 100, stats

    resource_language = text_resource.resource_languages.find(5)
    stats = text_resource.get_count_from_resource_stats(name, resource_language)
    assert_equal 150, stats
  end
end
