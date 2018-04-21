module ErrorReportsHelper
  def resolution_summary(error_report)
    if error_report.resolution.blank?
      content_tag(:span, 'None')
    else
      truncate(error_report.resolution, length: 60, omission: '...')
    end
  end
end
