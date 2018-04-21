require File.dirname(__FILE__) + '/../test_helper'

class ResourceChatsControllerTest < ActionController::TestCase
  fixtures :text_resources, :resource_chats, :resource_languages, :languages, :resource_strings, :string_translations,
           :user_sessions, :money_accounts

  def test_start_translations
    session = user_sessions(:amir)
    text_resource = text_resources(:amir_ready_to_start)

    # empty selected_chats
    post :start_translations, params: {
      selected_chats: [],
      text_resource_id: text_resource.id,
      session: session.session_num
    }

    assert :success
    assert_not_nil flash[:notice]

    # can pay
    selected_chats = ResourceChat.find([3, 4])
    post :start_translations, params: {
      selected_chats: selected_chats,
      text_resource_id: text_resource.id,
      session: session.session_num
    }

    assert :success
    assert_nil flash[:notice]

    # can't pay
    amir_acc = money_accounts(:amir)
    amir_acc.balance = 3
    amir_acc.save!

    selected_chats = ResourceChat.find([4, 5])
    post :start_translations, params: {
      selected_chats: selected_chats,
      text_resource_id: text_resource.id,
      session: session.session_num
    }

    assert :success
    assert_not_nil flash[:notice]
  end
end
