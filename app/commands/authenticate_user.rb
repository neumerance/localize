class AuthenticateUser
  prepend SimpleCommand

  def initialize(email, password, token = nil)
    @email = email
    @password = password
    @token = token
  end

  def call
    [JsonWebToken.encode(user_id: user.id), user] if user
  end

  private

  attr_accessor :email, :password, :token

  def user
    if token
      user = UserToken.user(token)
      return user if user.try(:webta_enabled?)
    else
      user = User.find_by_email(email)
      return user if user && user.authenticate(password) && user.webta_enabled?
    end

    errors.add :user_authentication, 'invalid credentials'
    nil
  end
end
