class ReportsController < ApplicationController
  prepend_before_action :setup_user, except: [:go]
  before_action :verify_supporter_privileges
  layout :determine_layout

  before_action :set_from_to_params_for_daily_search, only: [:eu_vat_by_state, :clients_projects]
  before_action :set_from_to_params_for_monthly_search, only: [:website_projects, :monthly_ta_projects]
  before_action :set_header, only: [:new_projects_count, :new_projects, :money_deposits, :money_spent, :money_per_project, :profit_loss_centers]

  def index; end

  def translation_analytics_campaing
    from = params[:campaing_from].to_time
    to = params[:campaing_to].to_time
    data = Report.campaing_report_data(from, to)
    send_data data, filename: 'campaing_report.csv', type: '/text/csv'
  end

  def profit_loss_centers
    from = params[:centers_from].to_time
    to = params[:centers_to].to_time
    data = Report.profit_loss_centers(from, to)

    send_data data, filename: 'campaing_report.csv', type: '/text/csv'
  end

  def money_per_project
    from = params[:money_from].to_time
    to = params[:money_to].to_time
    user = User.find_by(nickname: params[:user])
    data = user ? Report.money_per_project_data(from, to, user) : 'Invalid user'

    send_data data, filename: 'money_per_project.csv', type: '/text/csv'
  end

  def new_projects_count
    from = params[:count_from].to_time
    to = params[:count_to].to_time
    data = Report.new_projects_count_data(from, to)

    send_data data, filename: 'new_projects_count.txt', type: 'text'
  end

  def new_projects
    from = params[:new_from].to_time
    to = params[:new_to].to_time
    data = Report.new_projects_data(from, to)

    send_data data, filename: 'new_projects.csv', type: '/text/csv'
  end

  def money_deposits
    from = params[:deposits_from].to_time
    to = params[:deposits_to].to_time
    data = Report.money_deposits_data(from, to)

    send_data data, filename: 'money_deposits.csv', type: '/text/csv'
  end

  def money_spent
    from = params[:spent_from].to_time
    to = params[:spent_to].to_time
    data = Report.money_spent_data(from, to)

    send_data data, filename: 'money_spent.csv', type: '/text/csv'
  end

  def eu_vat_transactions
    conditions = [['status = ?', TXN_COMPLETED]]

    params[:from] ||= Date.today - 1.month
    params[:to]   ||= Date.today + 1.day

    if params[:from]
      from = params[:from].to_time
      to = params[:to].to_time + 1.day
      conditions << ['create_time > ? and create_time < ?', from, to]
    end

    if params[:tax_country_id] && params[:tax_country_id] != '0'
      country_id = params[:tax_country_id]
      conditions << ['tax_country_id = ?', country_id]
    else
      conditions << ['tax_country_id IN (?)', Country.require_vat_list]
    end

    conditions = simple_join_conditions_with_and(conditions)
    @invoices = Invoice.where(conditions)

    @totals = []
    @totals << @invoices.inject(0) { |mem, i| mem + i.gross_amount }
    @totals << @invoices.inject(0) { |mem, i| mem + i.tax_amount }
    @totals << @invoices.inject(0) { |mem, i| mem + (i.tax_amount + i.gross_amount) }

    if params[:commit] == 'Export to CSV'

      res = [['Invoice Id', 'Date', 'Payment method', 'Customer Name', 'Country', 'Code', 'Tax Rate', 'VAT ID', 'Amount', 'Tax Amount', 'Total Amount']]

      @invoices.each do |invoice|
        country = Country.find invoice.tax_country_id

        res << [
          invoice.id,
          invoice.create_time.to_date,
          Invoice::PAYMENT_PROCESSOR_TEXT[invoice.payment_processor],
          "#{invoice.user.fname} #{invoice.user.lname}",
          country.name,
          country.tax_code,
          "#{invoice.tax_rate}%",
          invoice.vat_number,
          invoice.gross_amount,
          invoice.tax_amount,
          invoice.gross_amount + invoice.tax_amount
        ]
      end
      res << ['', '', '', '', '', '', '', 'Totals:'] + @totals
      csv_txt = (res.collect { |row| (row.collect { |cell| cell.is_a?(Numeric) ? cell : "\"#{cell}\"" }).join(',') }).join("\n")

      send_data(csv_txt,        filename: 'eu_vat_transactions.csv',
                                type: 'text/plain',
                                disposition: 'downloaded')
    end

  end

  def eu_vat_by_state
    @countries = Country.where(tax_name: 'VAT').order('name ASC')

    @result = []
    @countries.each do |c|
      inv = Invoice.where(['status = ? AND tax_country_id = ? AND create_time > ? AND create_time < ?', TXN_COMPLETED, c.id, @from, @to])
      amount        = inv.inject(0) { |mem, i| mem + i.gross_amount }
      tax_amount    = inv.inject(0) { |mem, i| mem + i.tax_amount }
      total_amount  = inv.inject(0) { |mem, i| mem + (i.tax_amount + i.gross_amount) }

      @result << {
        name: c.name,
        code: c.code,
        tax_rate: "#{c.tax_rate}%",
        amount: amount,
        tax_amount: tax_amount,
        total_amount: total_amount
      }
    end

    @totals = []
    @totals << @result.inject(0) { |mem, i| mem + i[:amount] }
    @totals << @result.inject(0) { |mem, i| mem + i[:tax_amount] }
    @totals << @result.inject(0) { |mem, i| mem + i[:total_amount] }

    if params[:commit] == 'Export to CSV'

      res = [['Country', 'Code', 'Tax Rate', 'Amount', 'Tax Amount', 'Total Amount']]

      @result.each do |c|
        res << [c[:name], c[:code], c[:tax_rate], c[:amount], c[:tax_amount], c[:total_amount]]
      end

      res << ['', '', 'Totals:'] + @totals
      csv_txt = (res.collect { |row| (row.collect { |cell| cell.is_a?(Numeric) ? cell : "\"#{cell}\"" }).join(',') }).join("\n")

      send_data(csv_txt,        filename: 'eu_vat_by_state.csv',
                                type: 'text/plain',
                                disposition: 'downloaded')
    end

  end

  def website_projects
    conditions = [['cms_requests.status IN (?)', [CMS_REQUEST_RELEASED_TO_TRANSLATORS, CMS_REQUEST_TRANSLATED, CMS_REQUEST_DONE]]]

    @result = []
    time = params[:from]
    while time < params[:to]
      query_conds = conditions.dup
      query_conds << [
        'cms_requests.created_at > ? AND cms_requests.created_at < ?',
        time,
        time.at_end_of_month.to_time
      ]

      cms_requests = CmsRequest.
                     where(simple_join_conditions_with_and(query_conds)).
                     includes('website').
                     joins(:website)

      new_projects, recurring_projects = cms_requests.partition { |c| c.website.created_at.month == c.created_at.month }

      data = {
        key: time.strftime('%B %Y'),
        new_projects: new_projects.count.to_i,
        recurring_projects: recurring_projects.count.to_i,
        new_projects_wcount: new_projects.map { |c| c.word_count.to_i }.sum,
        recurring_projects_wcount: recurring_projects.map { |c| c.word_count.to_i }.sum
      }

      data[:total_projects] = data[:new_projects] + data[:recurring_projects]
      data[:total_projects_wcount] = data[:new_projects_wcount] + data[:recurring_projects_wcount]

      @result << data

      time = time.next_month
    end
  end

  def monthly_ta_projects
    @result = []
    @details = { manual: [], static: [] }
    time = params[:from]
    while time < params[:to]
      conditions = [
        'kind = ? AND creation_time > ? AND creation_time < ?',
        TA_PROJECT,
        time,
        time.at_end_of_month.to_time
      ]

      projects = Project.includes(:revisions).where(conditions)
      total_projects_count = projects.count

      result = {}
      [TA_PROJECT, MANUAL_PROJECT, SIS_PROJECT].each do |value|
        valid, projects = projects.partition { |c| c.source == value }
        result[value] = valid
      end

      cms_requests, projects = projects.partition { |p| p.revisions.try(:last).try(:cms_request_id) }
      @details[:manual] << result[MANUAL_PROJECT]
      @details[:static] << result[TA_PROJECT]
      data = {
        key: time.strftime('%B %Y'),
        help_manual: result[MANUAL_PROJECT].count,
        static_website: result[TA_PROJECT].count,
        cms_requests: cms_requests.count,
        sisualizer: result[SIS_PROJECT].count,
        other: projects.count,
        total: total_projects_count
      }

      @result << data

      time = time.next_month
    end
    @old_wpml = CmsUpload.where('chgtime > ?', params[:from])
  end

  def clients_projects
    @result = {}
    @projects = {}

    measure = lambda do |title, &block|
      r = Benchmark.measure(&block)
      logger.info "[Report time measure] #{title}: \n#{r}"
    end

    # Website projects
    measure.call('Website Projects') do
      conds = ['websites.created_at > ? AND websites.created_at < ?', @from, @to]
      @projects[:websites] = {
        paid: Website.where(conds).
                             joins(:cms_requests).
                             distinct.
                             merge(CmsRequest.paid).
                             group(:client_id).count,
        created: Website.where(conds).group(:client_id).count
      }
    end

    # Cms Jobs
    measure.call('CMS Jobs') do
      conds = ['cms_requests.created_at > ? AND cms_requests.created_at < ?', @from, @to]
      @projects[:cms_requests] = {
        paid: CmsRequest.where(conds).paid.joins(:website).distinct.group('websites.client_id').count,
        created: CmsRequest.where(conds).joins(:website).distinct.group('websites.client_id').count
      }
    end

    # IT Projects
    measure.call('IT Projects') do
      conds = ['web_messages.create_time > ? AND web_messages.create_time < ?', @from, @to]
      # we careful with owner type it should be User
      @projects[:it] = {
        paid: WebMessage.where(conds).funded.group(:owner_id).count,
        created: WebMessage.where(conds).group(:owner_id).count
      }
    end

    # Bidding projects (NOT CMS)
    measure.call('Bidding Projects non cms') do
      conds = ['revisions.creation_time > ? AND revisions.creation_time < ? AND revisions.cms_request_id is null', @from, @to]
      @projects[:bidding] = {
        paid: Revision.where(conds).joins(:project).distinct.group('projects.client_id').count,
        created: Revision.where(conds).joins(:project).distinct.group('projects.client_id').count
      }
    end

    # Software Projects
    measure.call('Software Projects') do
      conds = ['text_resources.created_at > ? AND text_resources.created_at < ?', @from, @to]
      @projects[:software] = {
        paid: TextResource.where(conds).
                             joins([resource_languages: [money_accounts: :account_lines]]).
                             distinct.
                             group(:client_id).count,
        created: TextResource.where(conds).group(:client_id).count
      }
    end

    # Organize result in a clients hash
    @projects.each do |project_kind, results|
      [:paid, :created].each do |status|
        results[status].each do |client_id, count|
          @result[client_id] ||= {}
          @result[client_id][project_kind] ||= { created: 0, paid: 0 }
          @result[client_id][project_kind][status] = count
        end
      end
    end

    @clients = User.select(:id, :nickname, :fname, :lname).where(id: @result.keys).index_by(&:id)

    # @ToDo not the best way to generate a CSV file, but faster for now.
    #   this is also used on eu_vat_by_state
    if params[:commit] == 'Export to CSV'
      res = [['Client ID', 'Nickname',
              'Websites Created', 'Websites Paid',
              'CMS Jobs Created', 'CMS Jobs Paid',
              'IT Created', 'IT Paid',
              'Bidding Created', 'Bidding Paid',
              'Software Created', 'Software Paid']]

      @result.each do |client_id, data|
        nickname = @clients[client_id]&.nickname || 'Unknown User'
        row = [client_id, nickname]
        row << %i(websites cms_requests it bidding software).map do |project_kind|
          [(data.dig(project_kind, :created) || 0),
           (data.dig(project_kind, :paid) || 0)]
        end
        res << row.flatten
      end

      # "Totals" row
      totals = []
      %i(websites cms_requests it bidding software).each do |project_kind|
        # to_i is required to convert nil values into 0
        totals << @result.inject(0) { |sum, x| sum + x[1].dig(project_kind, :created).to_i }
        totals << @result.inject(0) { |sum, x| sum + x[1].dig(project_kind, :paid).to_i }
      end
      res << ['', 'Totals:'] + totals

      csv_txt = (res.collect { |row| (row.collect { |cell| cell.is_a?(Numeric) ? cell : "\"#{cell}\"" }).join(',') }).join("\n")

      send_data(csv_txt,        filename: "clients_projects_#{@from}-#{@to}.csv",
                                type: 'text/plain',
                                disposition: 'downloaded')
    end
  end

  def review_usage
    params[:from] ||= (Time.zone.today - 1.month).beginning_of_month
    params[:to] ||= (Time.zone.today - 1.month).end_of_month
    if params[:to].present? && params[:to].to_date < params[:from].to_date
      flash[:notice] = 'Invalid date selection'
      redirect_to controller: 'reports', action: 'review_usage'
    end
    @results = CmsRequest.review_usage_report(params[:from], params[:to])
  end

  def automatic_translator_assignment_usage
    @automatic_translator_assignment = WebsiteTranslationOffer.automatic_translator_assignment_usage_report[0]
    @automatic_translator_assignment_per_language = WebsiteTranslationOffer.automatic_translator_assignment_usage_report(per_language: true)
  end

  private

  def set_header
    response.set_header('Set-Cookie', 'fileDownload=true; path=/')
  end

  def verify_supporter_privileges
    unless @user.has_supporter_privileges?
      set_err('You are not allowed to do this.')
      false
    end
  end

  # TODO: refactor
  def simple_join_conditions_with_and(conditions)
    c = ['']
    conditions.each do |x|
      c[0] << ' AND ' unless c[0].empty?
      c[0] += x[0]
      c += x[1..-1]
    end
    c
  end

  # Used on website_projects and ta_projects
  #
  def set_from_to_params_for_monthly_search
    if params[:from]
      params[:from] = Date.new(params[:from][:year].to_i, params[:from][:month].to_i).at_beginning_of_month.to_time
      params[:to]   = Date.new(params[:to][:year].to_i, params[:to][:month].to_i).at_end_of_month.to_time
    else
      params[:from] = (Time.now - 3.months).at_beginning_of_month.to_time
      params[:to]   = Time.now.at_end_of_month.to_time
    end
  end

  def set_from_to_params_for_daily_search
    params[:from] ||= Date.today - 1.month
    params[:to]   ||= Date.today + 1.day

    if params[:from]
      @from = params[:from].to_time
      @to = params[:to].to_time + 1.day
    end
  end
end
