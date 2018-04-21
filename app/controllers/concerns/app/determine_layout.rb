module App
  module DetermineLayout
    def determine_layout
      return 'application' if request.format == Mime[:json]
      cont = params[:controller]
      act = params[:action]
      if request.format.xml?
        'xmlbase'
      elsif (cont == 'web_dialogs') && !@user
        'web_supports'
      elsif (cont == 'login') ||
            ((cont == 'users') && ((act == 'new') || (act == 'create') || (act == 'reset_password'))) ||
            ((cont == 'contacts') && !(@user && @user.has_supporter_privileges?)) ||
            ((cont == 'web_dialogs') && !@user) ||
            ((cont == 'error_reports') && (act == 'resolution')) ||
            (cont == 'open_work') ||
            ((cont == 'my') && (act == 'invite')) ||
            (cont == 'tools') ||
            ((cont == 'text_resources') && ((act == 'quote_for_resource_translation') || (act == 'browse'))) ||
            (cont == 'newsletters') && !(@user && @user.has_admin_privileges?) ||
            (cont == 'apps')
        'external'
      elsif ((cont == 'client') && ((act == 'getting_started') || (act == 'getting_started4') || (act == 'translate_with_ta'))) ||
            ((cont == 'projects') && (act == 'new_sisulizer'))
        'light'
      elsif (cont == 'downloads') && !(@user && @user.has_supporter_privileges?)
        'download'
      elsif (cont == 'glossary_terms') && (act == 'ta_glossary_edit')
        'empty'
      elsif (cont == 'feedbacks') && %w(new create).include?(act)
        'feedback'
      elsif !params[:download].blank?
        'plain'
      elsif params[:compact] == '1'
        'compact'
      elsif !params[:printable].blank?
        'printable'
      else
        'standard'
      end
    end
  end
end
