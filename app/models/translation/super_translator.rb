module Translation
  class SuperTranslator < ActiveRecord::Base
    class << self
      def user_exists?(user)
        exists_by_email?(user.try(:email))
      end

      def exists_by_email?(email)
        where(email: email).take.present?
      end

      def assign_by_email!(email)
        create(email: email) unless exists_by_email?(email)
      end

      def assign_user!(user)
        assign_by_email!(user.try(:email))
      end
    end
  end
end
