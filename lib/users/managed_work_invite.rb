module Users
  class ManagedWorkInvite < InviteToJob
    def find_job
      @job = ManagedWork.find_by(id: job_id)

      Rails.logger.info "------ job class is #{job.class}"
      job = job.owner
      Rails.logger.info "-- changing to owner - #{job.class}"
    end

    def send_invite
      @problem = "Don't know how to invite to this project"
    end

    def permissions_ok?
      true
    end
  end
end
