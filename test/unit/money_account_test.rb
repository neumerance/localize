require File.dirname(__FILE__) + '/../test_helper'

class MoneyAccountTest < ActiveSupport::TestCase
  fixtures :money_accounts, :text_resources, :resource_chats, :resource_languages, :languages, :resource_strings, :string_translations
  def test_has_enough_money_for
    user_acc = money_accounts(:amir)
    text_resource = text_resources(:amir_ready_to_start)
    resource_chats = ResourceChat.find([3, 4])
    assert user_acc.has_enough_money_for(text_resource: text_resource, resource_chats: resource_chats)

    assert_raise(RuntimeError) { user_acc.has_enough_money_for(some_string: String.new) }
  end

  def test_has_enough_money_resources_chat
    user_acc = money_accounts(:amir)
    text_resource = text_resources(:amir_ready_to_start)
    resource_chats = ResourceChat.find([3, 4])

    assert user_acc.has_enough_money_for_resources_chat(text_resource, resource_chats)

    user_acc.balance = 0.08
    user_acc.save

    assert !user_acc.has_enough_money_for_resources_chat(text_resource, resource_chats)
  end
end
