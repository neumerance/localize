class Wpml::PendingPaymentsReportController < Wpml::BaseWpmlController
  before_action :authorize_user

  def index
    @header = 'Websites with pending payments and enough balance'
    @websites = Website.with_unpaid_cms_requests_and_enough_balance

    respond_to do |format|
      format.html # Render index.html.erb implicitly
      format.csv do
        headers['Content-Disposition'] = 'attachment; filename=\'websites_pending_payments.csv\''
        headers['Content-Type'] ||= 'text/csv'
        # Render index.csv.erb implicitly
      end
    end
  end

  def authorize_user
    # Only supporters can view this page
    raise Error::NotAuthorizedError unless @user.has_supporter_privileges?
  end
end
