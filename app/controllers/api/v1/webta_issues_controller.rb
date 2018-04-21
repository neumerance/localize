# THis controller is used to expose API to WebTA to handle issues from reviewers and translator
# for issues from WPML, look in issues_controller
class Api::V1::WebtaIssuesController < Api::V1::ApiController
  before_action :set_job

  def create_issue_by_mrk
    render json: @job.create_mrk_issue(params, @current_user)
  end

  def close_issue
    render json: @job.close_issue_by_webta(params[:id], @current_user)
  end

  def create_issue_message
    render json: @job.create_message_by_webta(params, @current_user)
  end

  def get_by_mrk
    render json: Issue.find_by_mrk(params)
  end

  def index
    render json: @job.find_mrks_count_by_cms_id
  end

  private

  def set_job
    if params[:job_id].to_i == 0
      @job = CmsRequestFake.new(@current_user)
      return @job
    end
    @job = CmsRequest.find_by_id(params[:job_id])
    return true if Translation::SuperTranslator.user_exists?(@current_user)

    @job = nil if @job.present? &&
                  @job.cms_target_language.translator != @current_user &&
                  @job.reviewer != @current_user
    raise ActionController::RoutingError, 'Not Found' if @job.nil?
  end
end
