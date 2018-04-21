class UserToken < ApplicationRecord

  belongs_to :translator, foreign_key: :user_id

  TOKEN_VALID_FOR = 155.minutes
  CLEAN_AFTER = 1.day

  def mark_as_used
    self.update_attribute(:used, true)
  end

  def usable?
    Time.now - self.created_at < TOKEN_VALID_FOR
  end

  class << self

    def user(token)
      user = nil
      auth_token = UserToken.where(token: token).last
      user = auth_token.try(:translator) if auth_token.try(:usable?)
      user
    end

    def create_token(user)
      return nil unless user.is_a? Translator
      self.create(translator: user,
                  token: Digest::MD5.hexdigest(SecureRandom.base64).parameterize)
    end

  end

end
