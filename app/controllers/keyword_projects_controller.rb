class KeywordProjectsController < ApplicationController
  prepend_before_action :setup_user
  before_action :verify_client, except: [:translate, :save_progress, :show, :download, :release_money, :destroy, :instructions, :example_doc]
  before_action :set_project, except: [:translate, :save_progress, :show, :download, :release_money, :destroy, :instructions, :example_doc]
  before_action :set_keyword_project, only: [:translate, :save_progress, :show, :download, :release_money, :destroy]
  layout :determine_layout, except: [:download]

  def example_doc
    file_path = Rails.root + '/private_docs/keyword localization example.pdf'
    send_file(file_path)
  end

  def instructions
    file_path = case params[:doc]
                when 'web'
                  Rails.root + '/private_docs/Keyword Localization Process for Websites.pdf'
                when 'app'
                  Rails.root + '/private_docs/Keyword Localization Process for Apps.pdf'
                when 'general'
                  Rails.root + '/private_docs/Keyword Localization Process for General Texts.pdf'
                end
    send_file(file_path)
  end

  def new
    @max_unused_keywords = 0
    @project.project_languages.each do |pl|
      remaining_keywords = pl.keyword_projects.where(status: KeywordProject::PAID).map do |kwp|
        kwp.purchased_keyword_packages.inject(0) { |a, b| a + b.remaining_keywords }
      end.inject(0) { |a, b| a + b }

      @max_unused_keywords = remaining_keywords if remaining_keywords > @max_unused_keywords
    end

    @project_languags_with_remaining_words = @project.project_languages.find_all { |pl| pl.remaining_keywords > 0 }
  end

  def show_keywords
    @keyword_sets = @project.keyword_projects.find_all { |kwp| kwp.keywords.any? }.map { |x| x.keywords.map(&:text) }.uniq
  end

  def show
    unless @user.has_supporter_privileges?
      return unless validate(@keyword_project.completed?, 'This project is not finished yet')
    end
  end

  def destroy
    @keyword_project.destroy
    flash[:notice] = 'Your package was removed!'
    redirect_to :back
  end

  def download
    respond_to do |format|
      format.pdf do
        render pdf: "keyword_localziation_report_#{@keyword_project.owner.project.name}_#{@keyword_project.owner.language.name}",
               layout: 'pdf.html',
               show_as_html: false,
               margin: { bottom: 20 },
               footer: { content: render_to_string(template: 'shared/footer.pdf.html') }
      end
    end
  end

  def release_money
    return unless validate(@user.has_supporter_privileges? || @keyword_project.owner.project.client == @user, "You can't do that.")
    return unless validate(@keyword_project.pending_approval?, 'This work is not waiting for your approval.')
    @keyword_project.pay_translator
    @keyword_project.pay!
    flash[:notice] = 'Project approved'
    redirect_to :back
  end

  def translate
    # Renders the template
    if @user.is_a?(Translator) && @keyword_project.status == 0
      validate(false, "This Keyword Project doesn't have enough funds to allow translation.")
    end

  end

  def free_sample
    return unless validate(@is_admin, 'Only supporters can give free keywords')
    return unless validate(params[:keywords_count].to_i > 0, 'You need to pick the number of keywords')
    return unless validate(params[:language_ids], 'You must select at least one language')

    languages = Language.find(params[:language_ids])
    KeywordProject.create_free_samples(@project, languages, params[:keywords_count])

    flash[:notice] = 'Keywords add'
    redirect_to_project_page(@project)
  end

  def collection_create
    return unless validate(params[:language_ids], 'You must select at least one language')

    keyword_package = KeywordPackage.find_by(id: params[:keyword_package_id])
    return unless validate(keyword_package, 'You must select a keyword package')
    return unless validate(params[:keywords] && params[:keywords].any? { |x| !x.blank? }, 'You must have at least one keyword')
    keywords_texts = params[:keywords].delete_if(&:blank?)

    if keyword_package.reuse_package?
      return unless languages_have_enough_keywords(@project, params[:language_ids], keywords_texts.size)
    end

    languages = Language.find(params[:language_ids])
    KeywordProject.create_new_packages(@project, languages, keyword_package, keywords_texts)

    flash[:notice] = if keyword_package.reuse_package?
                       'Keyword localization requested. It will start right away.'
                     elsif @project.is_a? TextResource
                       'Keyword localization requested. Please choose a translator to pay and get the work started'
                     else
                       'Keyword localization requested. You can pay it now to start the work, or continue setting up your project.'
                     end

    redirect_to_project_page(@project)
  end

  def save_progress
    ActiveRecord::Base.transaction do
      keywords = @keyword_project.keywords
      keywords.each { |keyword| keyword.save_progress(params[:keywords][keyword.id.to_s]) }
      if params[:keyword_project][:comments].blank?
        @keyword_project.update_attribute :comments, nil
      else
        @keyword_project.update_attribute :comments, params[:keyword_project][:comments]
      end

      case params[:commit]
      when 'save'
        flash[:notice] = 'Progress saved'
        redirect_to :back
      when 'deliver'
        unfilled_keywords = keywords.find_all { |kw| not kw.filled? }
        if @keyword_project.completed?
          flash[:notice] = 'Project already delivered!'
          redirect_to :back
        elsif unfilled_keywords.any?
          indexes = []
          unfilled_keywords.each do |unfilled_kw|
            indexes << keywords.index(unfilled_kw) + 1
          end
          flash[:notice] = "You must fill in all the fields before delivering. Keywords #{indexes.to_sentence} are incomplete"
          redirect_to :back
        elsif keywords.any? { |k| k.keyword_translations.any? { |kt| kt.reload; kt.hits.to_i < 0 } }
          flash[:notice] = 'All monthly hits must be filled with numbers'
          redirect_to :back
        elsif @keyword_project.comments.blank?
          flash[:notice] = 'You are expected to add some general comments about your work to the client, on the bottom of the page'
          redirect_to :back
        else
          @keyword_project.complete!
          flash[:notice] = 'Your project was delivered.'
          redirect_to @keyword_project
        end
      end
    end
  end

  private

  def redirect_to_project_page(project)
    if project.is_a? Revision
      redirect_to [project.project, project]
    else
      redirect_to project
    end
  end

  def set_keyword_project
    @keyword_project = KeywordProject.find(params[:id])
    can_edit = if %(show download).include? params[:action]
                 @user.has_supporter_privileges? ||
                   @user.has_translator_privileges? ||
                   @keyword_project.owner.project.client == @user
               elsif %(destroy release_money).include? params[:action]
                 @user.has_supporter_privileges? ||
                   @keyword_project.owner.project.client == @user
               else
                 @user.has_supporter_privileges? ||
                   @keyword_project.owner.translator == @user
               end
    validate(can_edit, "You can't edit this.")
  end

  def set_project
    unless %w(TextResource Revision Website).include? project_type
      set_err('Invalid project type')
      return false
    end

    project_type =
      case params[:project_type]
      when 'Website'
        Website
      when 'TextResource'
        TextResource
      when 'Revision'
        Revision
      end

    unless (Integer(params[:project_id]) rescue false)
      set_err('Invalid project id')
      return false
    end

    @project = project_type.find(params[:project_id])

    if @user.has_admin_privileges?
      @is_admin = true
      @user = @project.client
    else
      @is_admin = false
    end

    unless @user == @project.client
      set_err('Not your project')
      return false
    end
  end

  def validate(condition, message)
    if condition
      true
    else
      flash[:notice] = message
      redirect_to :back, params
      false
    end
  end

  def every_language_have_a_translator(language_ids)
    languages = Language.find(language_ids)
    selected_langs = @project.project_languages.find_all { |pl| languages.include?(pl.language) }
    langs_with_no_translator = selected_langs.find_all { |lang| lang.translator.nil? }
    if langs_with_no_translator.any?
      if langs_with_no_translator.size == 1
        validate(false, "The language #{langs_with_no_translator.first.language.name} have no translators")
      else
        validate(false, "The languages #{langs_with_no_translator.map { |pl| pl.language.name }.join(', ')} have no translators")
      end
    else
      true
    end
  end

  def languages_have_enough_keywords(project, language_ids, word_count_needed)
    project_languages = project.project_languages.find_all { |x| language_ids.include?(x.language_id.to_s) }
    raise 'Could not find all selected languages in the project' if project_languages.size < language_ids.size

    langs_with_no_enough_keywords = project_languages.find_all { |lang| lang.remaining_keywords < word_count_needed }
    if langs_with_no_enough_keywords.empty?
      true
    else
      msg = "The following languages have less keywords left:\n"
      langs_with_no_enough_keywords.each do |lang|
        msg += if lang.remaining_keywords > 0
                 "#{lang.language.name} has only #{lang.remaining_keywords} keywords left."
               else
                 "#{lang.language.name} has no keywords left."
               end
      end
      flash[:notice] = msg
      redirect_to :back
      false
    end
  end

end
