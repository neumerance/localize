# This controller is used to record issues reported by WPML via TP
# for issues created by translators/reviewers via WebTA chack webta_issues_controller
class Api::V1::IssuesController < Api::V1::ApiController

  skip_before_action :authenticate_request

  def create
    render json: Issue.create_by_api(JSON.parse(request.body.read))
  end

  def show
    render json: Issue.get_by_api(params[:id])
  end
end
