require "#{File.dirname(__FILE__)}/../test_helper"

class SupportTicketsTest < ActionDispatch::IntegrationTest
  fixtures :users, :support_departments

  def test_ticket

    init_email_deliveries

    user = users(:amir)
    assert Admin.count > 1

    department = support_departments(:normal)

    session = login(user)

    get(url_for(controller: :support, action: :new),
        session: session)
    assert_response :success

    tickets_count = SupportTicket.count

    ticket_subject = 'This is the ticket'
    ticket_message = 'I need help here'
    post(url_for(controller: :support, action: :create),
         support_ticket: { support_department_id: department.id, subject: ticket_subject, message: ticket_message },
         session: session)
    assert_response :redirect

    assert_equal tickets_count + 1, SupportTicket.count

    support_ticket = SupportTicket.all.to_a[-1]

    assert support_ticket
    assert_equal ticket_subject, support_ticket.subject
    assert_equal 1, support_ticket.messages.count
    assert_nil support_ticket.supporter

    check_emails_delivered(1) # changed to 1 because now notification email is only sending once to multiple admin emails.

    # user can see the ticket
    get(url_for(controller: :support, action: :show, id: support_ticket.id),
        session: session)
    assert_response :success

    # add another message to the ticket. Still, all admins are notified
    post(url_for(controller: :support, action: :create_message, id: support_ticket.id),
         body: 'This is another message',
         session: session)
    assert_response :redirect

    support_ticket.reload
    assert_equal 2, support_ticket.messages.count

    check_emails_delivered(Admin.count)

    # ---- admin replies and takes ownership ----
    admin = users(:admin)
    asession = login(admin)

    # admin can see the ticket
    get(url_for(controller: :support, action: :show, id: support_ticket.id),
        session: asession)
    assert_response :success

    # add another message to the ticket. Still, all admins are notified
    post(url_for(controller: :support, action: :create_message, id: support_ticket.id),
         body: 'This is my reply',
         session: asession)
    assert_response :redirect

    support_ticket.reload
    assert_equal 3, support_ticket.messages.count

    # only the user is notified
    check_emails_delivered(1)

    # admin assumes responsibility
    post(url_for(controller: :support, action: :assume_responsibility, id: support_ticket.id),
         body: 'This is my reply',
         session: asession)
    assert_response :redirect

    support_ticket.reload
    assert_equal 3, support_ticket.messages.count
    assert_equal admin, support_ticket.supporter

    logout(asession)

    # ---- user adds another message, now, only assigned admin gets it ----

    # add another message to the ticket. Still, all admins are notified
    post(url_for(controller: :support, action: :create_message, id: support_ticket.id),
         body: 'Message only to admin',
         session: session)
    assert_response :redirect

    support_ticket.reload
    assert_equal 4, support_ticket.messages.count

    check_emails_delivered(1)

    logout(session)

  end

  def test_new_support_ticket_for_user
    # get test
    user = users(:amir)
    session = login(user)
    get(url_for(controller: :support, action: :new_support_ticket_for_user, id: user.id), session: session)
    assert_response :success

    # empty post
    params = { subject: 'test' }
    post(url_for(controller: :support, action: :create_support_ticket_for_user, id: user.id), { session: session }, params)
    assert flash[:notice]

    # subject only
    params = { message: 'test' }
    post(url_for(controller: :support, action: :create_support_ticket_for_user, id: user.id), { session: session }, params)
    assert flash[:notice]

    # attachment only
    file = { uploaded_data: 'test.pdf' }.to_s
    params = { file1: file }
    post(url_for(controller: :support, action: :create_support_ticket_for_user, id: user.id), { session: session }, params)
    assert flash[:notice]

    # no attachment
    params = { subject: 'test', message: 'test' }
    post(url_for(controller: :support, action: :create_support_ticket_for_user, id: user.id), { session: session }, params)
    assert :success

    # attachment
    params = { subject: 'test', message: 'test', file1: file }
    post(url_for(controller: :support, action: :create_support_ticket_for_user, id: user.id), { session: session }, params)
    assert :success

    # attachments
    params = { subject: 'test', message: 'test', file1: file, file2: file, file3: file }
    post(url_for(controller: :support, action: :create_support_ticket_for_user, id: user.id), { session: session }, params)
    assert :success
  end

end
