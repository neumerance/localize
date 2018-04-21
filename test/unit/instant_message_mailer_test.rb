require File.dirname(__FILE__) + '/../test_helper'

# TODO: actually test checks only that email were created. spetrunin 10/20/2016
class InstantMessageMailerTest < ActionMailer::TestCase
  fixtures :users, :web_supports, :client_departments, :web_dialogs, :web_messages, :languages
  tests InstantMessageMailer

  def test_confirm
    dialog = web_dialogs(:amir_sales_for_translation)

    confirmation = InstantMessageMailer.confirm(dialog, nil)
    assert confirmation
  end

  def test_notify_visitor
    dialog = web_dialogs(:amir_sales_for_translation)
    message = web_messages(:message_for_amir_sales)

    notification = InstantMessageMailer.notify_visitor(dialog, message, nil)
    assert notification
  end

  def test_notify_client
    dialog = web_dialogs(:amir_sales_for_translation)
    message = web_messages(:message_for_amir_sales)

    notification = InstantMessageMailer.notify_client(dialog, message, false)
    assert notification

    notification = InstantMessageMailer.notify_client(dialog, message, true)
    assert notification
  end

  def test_instant_translation_complete
    message = web_messages(:standalone_message)

    notification = InstantMessageMailer.instant_translation_complete(message)
    assert notification
  end

end
