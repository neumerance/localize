module TranslationAnalyticsBaseHelper
  def default_parameters
    "?project_type=#{params[:project_type]}&project_id=#{params[:project_id]}"
  end

  def translation_analytics_tabs(selected_tab)
    [
      { text: 'Overview', link: overview_link, selected: selected_tab == :overview, class: 'mc-ioverview' },
      { text: 'Progress Graph', link: progress_graph_link, link_class: 'mc-two-lines', selected: selected_tab == :progress_graph, class: 'mc-iprogressgraph' },
      { text: 'Alerts', link: alerts_link, selected: selected_tab == :alerts, class: 'mc-ialerts' }
    ]
  end

  def project_parameters
    "?project_type=#{@project.class}&project_id=#{@project.id}"
  end

  def cms_parameters
    "&from_cms=#{params[:from_cms]}&accesskey=#{params[:accesskey]}"
  end

  def overview_link
    overview_translation_analytics_url + project_parameters + cms_parameters
  end

  def details_link
    details_translation_analytics_url +  project_parameters + cms_parameters
  end

  def deadlines_link
    deadlines_translation_analytics_url + project_parameters + cms_parameters
  end

  def progress_graph_link
    progress_graph_translation_analytics_url + project_parameters + cms_parameters
  end

  def dismiss_alert_setup_link
    dismiss_alert_setup_translation_analytics_url + project_parameters + cms_parameters
  end

  def alerts_link
    "/translation_analytics_profiles/#{@project.translation_analytics_profile.id}/edit" + project_parameters + cms_parameters
  end
end
