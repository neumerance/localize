module Users
  class InviteToJob
    attr_reader :job_id, :message, :auser
    attr_accessor :job, :problem, :redirect

    def self.instantiate_inviter(project_type, params, auser, user)
      args = [params, auser, user]

      case project_type
      when 'RevisionLanguage'
        RevisionLanguageInvite.new(*args)
      when 'ResourceLanguage'
        ResourceLanguageInvite.new(*args)
      when 'WebsiteTranslationOffer'
        WebsiteTranslationInvite.new(*args)
      when 'ManagedWork'
        ManagedWorkInvite.new(*args)
      end
    end

    def initialize(params, auser, user)
      @job_id = params[:job_id].to_i
      @message = params[:message]
      @auser = auser
      @user = user
    end

    def find_job
      raise 'Not Implemented'
    end

    def send_invite
      raise 'Not Implemented'
    end

    def permissions_ok?
      raise 'Not Implemented'
    end
  end
end
