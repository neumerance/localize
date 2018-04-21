require File.dirname(__FILE__) + '/../test_helper'

class UserTest < ActiveSupport::TestCase
  fixtures :users
  fixtures :user_sessions

  def test_copied_email
    user = NormalUser.new(
      fname: 'jack',
      lname: 'tested',
      password: 'jack',
      email: users(:amir).email
    )

    assert !user.save
  end

  def test_bad_email
    user = NormalUser.new(
      fname: 'jack',
      lname: 'tested',
      password: 'jack',
      email: 'jack@com'
    )

    assert !user.save
  end

  def test_unique_email
    user = NormalUser.new(
      nickname: 'jojo',
      fname: 'jack',
      lname: 'tested',
      password: 'jack',
      email: 'jack@jack.com'
    )

    assert user.save
  end

  def test_last_login
    user = users(:shark)
    us = user_sessions(:shark)

    assert_equal user.id, us.user_id
    assert_equal user.last_login, us.login_time
  end
end
