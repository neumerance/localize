class ReminderMailerPreview < ActionMailer::Preview
  def generic
    ReminderMailer.generic('receiver@example.com', 'subject', 'message')
  end

  def cms_project_needs_money
    user = User.new(fname: 'First', lname: 'Last')
    website = Website.new(name: 'MySite')
    invoice = Invoice.new(currency: Currency.first, gross_amount: 50)

    ReminderMailer.cms_project_needs_money(user, website, invoice)
  end

  def welcome_site_user
    user = User.new(fname: 'First', lname: 'Last')

    ReminderMailer.welcome_site_user(user)
  end
end
