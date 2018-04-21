require File.dirname(__FILE__) + '/../test_helper'

class UserAccountTest < ActiveSupport::TestCase

  fixtures :user_accounts, :text_resources, :resource_chats, :resource_languages, :languages, :resource_strings, :string_translations
  def test_has_enough_money_for
    assert true
  end

  def test_has_enough_money_resources_chat
    user_acc = user_accounts(:amir_ua)
    text_resource = text_resources(:amir_ready_to_start)
    resource_chats = [3, 4]

    assert user_acc.has_enough_money_for_resources_chat(text_resource, resource_chats)

  end
end
