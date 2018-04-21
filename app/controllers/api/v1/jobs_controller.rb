class Api::V1::JobsController < Api::V1::ApiController
  before_action :set_job, except: [:index, :preview]
  skip_before_action :authenticate_request, only: [:preview]

  def index
    Profiling::IclMemoryProfiler.dump_if_need

    render json: @current_user.webta_jobs(params[:type], params[:page], params[:per].try(:to_f), params[:sort], params[:sort_order], params[:job_id])
  end

  def show
    @job.auto_save_untranslatable_mrks
    render json: @webta_format
  end

  def save
    render json: @job.save_webta_progress(params[:xliff_id], params[:mrk]).to_json
  end

  def complete
    render json: @job.complete_webta(@current_user).to_json
  end

  def preview
    @job = params[:id].to_i == 0 ? CmsRequestFake.new : CmsRequest.find(params[:id])
    render html: @job.preview.html_safe
  end

  private

  def set_job
    if params[:id].to_i == 0
      @job = CmsRequestFake.new(@current_user)
      @webta_format = @job.webta_format if params[:action] == 'show'
      return @job
    end
    @job = CmsRequest.includes(:xliff_trans_unit_mrks).find_by_id(params[:id])
    @webta_format = @job.webta_format(@current_user, params[:translation_type]) if params[:action] == 'show'
    return true if Translation::SuperTranslator.user_exists?(@current_user)

    @job = nil if @job.present? &&
                  @job.cms_target_language.translator != @current_user &&
                  @job.reviewer != @current_user
    raise ActionController::RoutingError, 'Not Found' if @job.nil?
  end
end
