require "#{File.dirname(__FILE__)}/../test_helper"

class EmailParseTest < ActionDispatch::IntegrationTest

  def test_process_email
    ec = EmailChecker.new

    files = ['email_1.txt', 'email_2.txt', 'email_3.txt', 'email_4.txt']

    files.each do |fname|

      f = File.open("#{File.expand_path(Rails.root)}/test/fixtures/email/#{fname}", 'rb')

      txt = f.read
      f.close

      cleaned = ec.clean_reply(txt)

      f = File.open("#{File.expand_path(Rails.root)}/test/fixtures/email/expected_#{fname}", 'rb')
      expected = f.read
      f.close

      assert_equal expected, cleaned
    end
  end

end
