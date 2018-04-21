# require 'gettext/tools'
require 'zip/zip'
require 'rexml/document'
require 'get_pomo/mo_file'

class TextResourcesController < ApplicationController
  prepend_before_action :setup_user, except: [:quote_for_resource_translation, :browse, :get]
  before_action :locate_resource, except: [:searcher, :index, :new, :create, :quote_for_resource_translation, :target_languages]
  before_action :verify_client, except: [:quote_for_resource_translation, :browse, :get, :searcher]
  before_action :setup_help, except: [:quote_for_resource_translation, :browse, :get]
  before_action :create_reminders_list, only: [:index, :show]
  before_action :verify_modify, only: [:create_translations]
  layout :determine_layout

  include CharConversion
  include ::ProcessorLinks
  include ::ReuseHelpers
  include ::UpdateSupporterDataAction

  DEFAULT_REQUIRED_TEXT = '<,>,"'.freeze

  def index
    @header = _('Software localization projects')
    @text_resources = @user.text_resources
  end

  def searcher
    unless @user.is_client?
      set_err('You cannot access this page')
      false
    end

    name_filter = params[:project_filter]
    name_filter = '' if name_filter.nil?
    @text_resources = @user.text_resources.
                      where('text_resources.name LIKE ?', "%#{name_filter}%").
                      order('text_resources.id DESC').page(params[:page]).per(PER_PAGE_SUMMARY)
    @text_resources_message = if @text_resources.total_pages > 1
                                _('Page %d of %d of software localization projects') % [@text_resources.current_page, @text_resources.total_pages] +
                                  "&nbsp;&nbsp;&nbsp;<a href=\"#{url_for(controller: :text_resources, action: :index, anchor: 'project_list')}\">" + _('Older software localization projects') + '</a>'
                              else
                                _('Showing all your software localization projects')
                              end
  end

  def new
    @header = _('Create a new software localization project')

    @text_resource = TextResource.new
    @text_resource.required_text = DEFAULT_REQUIRED_TEXT

    # check a an owner has been set
    if !params[:owner_type].blank? && !params[:owner_id].blank?
      if params[:owner_type] == 'WebSupport'
        begin
          owner = WebSupport.find(params[:owner_id].to_i)
        rescue
          set_err('This owner does not exist')
          return
        end
        @text_resource.owner = owner
        @text_resource.name = "Department names for '%s' support center" % owner.name
        @text_resource.description = 'The strings for translation in this project are names of support department belonging to a support center.'
      end
    end

    @languages = Language.have_translators
    @categories = Category.list
  end

  def create
    @text_resource = TextResource.new(params[:text_resource])

    bad_owner = false
    begin
      owner = @text_resource.owner
    rescue
      bad_owner = true
    end

    if bad_owner || @text_resource.owner_type.blank? || @text_resource.owner_id.blank?
      @text_resource.owner_type = nil
      @text_resource.owner_id = nil
    end

    if @user.alias?
      @text_resource.alias = @user
      @text_resource.client = @user.master_account
    else
      @text_resource.alias = nil
      @text_resource.client = @user
    end

    if @text_resource.save
      @text_resource.add_languages(params[:language].keys) if params[:language]

      redirect_to @text_resource
    else
      @header = _('Create a new software localization project')
      @formats = ResourceFormat.where('LOWER(name) <> ?', 'django').collect { |f| [f.name, f.id] }
      @languages = Language.have_translators
      @categories = Category.list
      render action: :new
    end
  end

  def reuse_translators
    if @text_resource.resource_languages.empty?
      flash[:notice] = 'You have not selected any language yet.'
      redirect_to :back
      return
    end

    project_hash = JSON.parse(params[:project])
    project_to_reuse = project_hash['class'].constantize.find(project_hash['id'])

    translator_for_language = languages_and_translators_to_reuse(project_to_reuse)
    reviewer_for_language = languages_and_reviewers_to_reuse(project_to_reuse)

    missing_rls = @text_resource.resource_languages.find_all { |rl| rl.selected_chat.nil? }

    flash[:notice] = ''
    missing_rls.each do |rl|
      translator = translator_for_language[rl.language]
      reviewer = reviewer_for_language[rl.language]
      next unless translator
      if rl.managed_work && rl.managed_work.translator_id == translator.id
        rl.managed_work.update_attribute :translator_id, nil
      end

      rl.set_reviewer(reviewer) if reviewer

      resource_chat = @text_resource.resource_chats.find_by(translator_id: translator.id)

      unless resource_chat
        resource_chat = @text_resource.resource_chats.new
        resource_chat.resource_language = rl
        resource_chat.translator = translator
        resource_chat.save!
      end
      resource_chat.accept

      params = { body: "Hi, I'm assigning you to this project since we already worked together on #{project_to_reuse.name}.\nThanks in advance." }
      message = resource_chat.create_message(@text_resource.client, params)
      translator.notify_new_message(resource_chat, message)

      flash[:notice] += "#{translator.nickname} is now your translator to #{rl.language.name}\n"
    end
    flash[:notice] = 'Could not find any translator to reuse' if flash[:notice].blank?

    redirect_to :back
  end

  def show
    @header = _('Software localization')
    @languages = Rails.cache.fetch("#{@text_resource.cache_key}/languages", expires_in: CACHE_DURATION) do
      @text_resource.resource_languages.includes(:language, :selected_chat, :managed_work, :feedbacks).collect { |rl| [rl.language.name, rl.language.id] }
    end

    @resource_formats = ResourceFormat.where('LOWER(name) <> ?', 'django').order('description ASC')

    resource_uploads = Rails.cache.fetch("#{@text_resource.cache_key}/resource_uploads", expires_in: CACHE_DURATION) do
      @text_resource.resource_uploads.includes(:text_resource, :resource_upload_format, :upload_translations, :resource_downloads)
    end

    @pager = ::Paginator.new(resource_uploads.count, 10) do |offset, per_page|
      resource_uploads.where('status = 1').limit(per_page).offset(offset).order('id DESC')
    end
    params[:page] ||= 1
    session[:last_ajax_page] = params[:page]
    @resource_uploads = @pager.page(params[:page])
    @list_of_pages = []
    for idx in 1..@pager.number_of_pages
      @list_of_pages << idx
    end
    @show_number_of_pages = @pager.number_of_pages > 1
    # end pagination

    @resource_translations = @text_resource.resource_translations.where(by_user_id: @text_resource.client.id)
    @resource_downloads = @text_resource.resource_downloads.includes(:text_resource, :upload_translation, :resource_download_stat)
    @review_languages = @text_resource.managed_works(@user)

    @projects_to_reuse = projects_to_reuse if @user.has_client_privileges?

    @next_string_to_review = {}
    @something_to_review = false
    @review_languages.each do |rl|
      language = rl.language
      # check that translation is complete
      untranslated_string =
        @text_resource.resource_strings.
        joins(:string_translations).
        where('(resource_strings.master_string_id IS NULL) AND (string_translations.language_id=?) AND (string_translations.status=?)',
              language.id,
              STRING_TRANSLATION_BEING_TRANSLATED).first

      if !untranslated_string
        @next_string_to_review[language] =
          @text_resource.resource_strings.
          joins(:string_translations).
          where('(string_translations.language_id=?) AND (string_translations.status=?) AND (string_translations.review_status=?)',
                language.id,
                STRING_TRANSLATION_COMPLETE,
                REVIEW_PENDING_ALREADY_FUNDED).first
        logger.info "------- @next_string_to_review[#{language.name}]: #{@next_string_to_review[language] ? @next_string_to_review[language].id : 'nothing'}"
        @something_to_review = true if @next_string_to_review[language]
      else
        logger.info "------------ got untranslated string: #{untranslated_string.id}"
      end
    end

    unless @something_to_review
      @review_languages.each do |rl|
        if rl.managed_work.translation_status == MANAGED_WORK_REVIEWING
          rl.managed_work.update_attributes(translation_status: MANAGED_WORK_COMPLETE)
        end
      end
    end

    if @text_resource.resource_format.nil?
      iphone_format = ResourceFormat.find_by(name: 'iPhone')
      @text_resource.resource_format = iphone_format
    end
  end

  def new_existing_translation
    if (@text_resource.resource_languages.count == 0) || (@text_resource.resource_strings.count == 0) || @text_resource.resource_format.nil?
      flash[:notice] = _('Cannot add existing translations right now')
      redirect_to action: :show
      return
    end

    @header = _('Add existing translation')
    @languages = [[_('-- Select --'), 0]] + @text_resource.resource_languages.collect { |rl| [rl.language.name, rl.language.id] }
    @resource_formats = ResourceFormat.where('LOWER(name) <> ?', 'django').order('description ASC')
    @contexts = []
    context_keys = {}
    @text_resource.resource_strings.each do |resource_string|
      context_keys[resource_string.context] = true
    end
    @contexts = context_keys.keys
  end

  def clear_notifications
    begin
      resource_language = @text_resource.resource_languages.find(params[:resource_language_id].to_i)
    rescue
      set_err('could not find this language')
      return
    end

    resource_language.sent_notifications.delete_all
    flash[:notice] = _('New translator notifications will be sent over the next hour.')
    redirect_to action: :show
  end

  def edit_description
    @header = "Edit the project's description"
    @categories = Category.list
  end

  def update
    unless @user.can_modify?(@text_resource)
      flash[:notice] = "You don't have permission to do that"
      redirect_to action: :show
      return
    end

    params[:text_resource][:required_text].gsub!(/(.*),\s*/, '\1')
    if @text_resource.update_attributes(params[:text_resource])
      flash[:notice] = 'Project updated'
      redirect_to action: :show
    else
      @header = "Edit the project's description"
      render action: :edit_description
    end
  end

  def comment_strings
    @header = 'String comments review'
    @unclear_strings = @text_resource.unclear_strings(params)
    @one_word_strings = []
    @placeholder_strings = []
    @other_strings = []
    @unclear_strings.each do |s|
      if s.unclear? && s.has_only_one_word
        @one_word_strings << s
      elsif s.unclear? && s.has_placeholders
        @placeholder_strings << s
      else
        @other_strings << s
        # raise "This string #{s.inspect} is unclear and should't be!"
      end
    end
  end

  # method used on /text_resources/new to get list of target languages
  def target_languages
    params[:req] = 'show'
    @text_resource = TextResource.new language_id: params[:language_id]
    edit_languages
    render partial: 'translation_languages'
  end

  def edit_languages
    req = params[:req]
    @show_edit_languages = nil # set the default value - don't show the list

    if req == 'show'
      @show_edit_languages = true

      @languages = {}

      to_lang = Language.to_languages_with_translators(@text_resource.language_id, true)

      to_lang.each do |lang|
        @languages[lang.name] = [lang.id, false, lang.major]
      end

      for rev_lang in @text_resource.resource_languages
        if @languages.key?(rev_lang.language.name)
          @languages[rev_lang.language.name][1] = true
        end
      end

    elsif req == 'save'
      begin
        to_lang_list = make_dict(params[:language])
      rescue
        to_lang_list = []
      end

      # remember the number of languages before we started
      orig_num_languages = @text_resource.resource_languages.length

      # drop any current language that's not marked
      to_remove = []
      for rev_lang in @text_resource.resource_languages
        to_remove << rev_lang unless to_lang_list.include?(rev_lang.language_id)
      end

      added_language = false # indicates if a new language was added
      not_deleted = []
      for rev_lang in to_remove
        # make sure that this language has no accepted chat
        if rev_lang.selected_chat || (rev_lang.find_or_create_account(DEFAULT_CURRENCY_ID).balance > 0)
          not_deleted << rev_lang
        end
      end

      if !not_deleted.empty?
        @warning = _("Some languages could not be removed because translation has already started on them:\n")
        for rev_lang in not_deleted
          @warning = @warning + rev_lang.language.name + "\n"
        end
      else

        # delete the unneeded languages
        for rev_lang in to_remove
          rev_lang.destroy
        end

        # add any language that doesn't yet appear
        @text_resource.add_languages to_lang_list
      end

      @text_resource.reload

      flash[:notice] = @warning if @warning

      redirect_to action: :show, id: @text_resource.id, anchor: 'translation_languages'
      return
    end
  end

  def add_po_translation

    resource_language = @text_resource.resource_languages.find_by(language_id: params[:language_id].to_i)
    unless resource_language
      set_err('Cannot find this language')
      return
    end

    language_id = resource_language.language_id

    po = if !params[:po_upload].blank?
           scan_po(params[:po_upload])
         else
           {}
         end

    ignored_count = 0
    changed_count = 0
    po.each do |k, v|
      if !v[0].blank? && (v[0] != '')
        resource_strings = @text_resource.resource_strings.where(txt: k)
        resource_strings.each do |resource_string|
          string_translation = resource_string.string_translations.find_by(language_id: language_id)
          if !string_translation
            string_translation = StringTranslation.new(txt: v[0], language_id: language_id, status: STRING_TRANSLATION_COMPLETE)
            string_translation.resource_string = resource_string
            string_translation.save!
            changed_count += 1
          elsif string_translation.txt.blank?
            string_translation.update_attributes!(txt: v[0], status: STRING_TRANSLATION_COMPLETE)
            changed_count += 1
          else
            ignored_count += 1
          end
        end
      else
        ignored_count += 1
      end
    end

    flash[:notice] = _('Updated %d strings, ignored %d') % [changed_count, ignored_count]
    redirect_to action: :show

  end

  # transfer = TRANSFER_DEPOSIT_TO_RESOURCE_TRANSLATION_WITH_REVIEW_AND_KEYWORDS
  # transfer = TRANSFER_DEPOSIT_TO_RESOURCE_REVIEW_WITH_KEYWORDS
  # transfer = TRANSFER_DEPOSIT_TO_RESOURCE_KEYWORDS
  def deposit_payment
    money_account = @text_resource.client.find_or_create_account(DEFAULT_CURRENCY_ID)
    total = 0
    resource_language_costs = []
    @text_resource.resource_languages.includes(:language, :selected_chat).each do |resource_language|
      transaction_code = params["transaction_code#{resource_language.id}"].to_i
      next if params["resource_language#{resource_language.id}"] != '1'
      next unless resource_language.selected_chat
      cost = (transaction_code == TRANSFER_DEPOSIT_TO_RESOURCE_REVIEW ? resource_language.review_cost : resource_language.cost)
      next unless cost && cost > 0
      total += cost
      resource_language_costs << [cost, resource_language, transaction_code]
    end

    total -= money_account.balance
    if resource_language_costs.empty?
      flash[:notice] = _('Nothing selected for payment')
      redirect_to action: :show
      return
    end
    if total <= 0
      flash[:notice] = _('You have enough money for the selected languages. Please start the work through the languages table.')
      redirect_to action: :show
      return
    end

    amount = total.round_money

    # send to PayPal to complete this payment
    invoice = create_invoice_for_resource_languages(DEFAULT_CURRENCY_ID, money_account, @user, @text_resource, amount, resource_language_costs)
    invoice_payment_link = paypal_pay_invoice(invoice, @user,
                                              url_for(controller: :text_resources, action: :show, id: @text_resource.id))

    redirect_to invoice_payment_link

  end

  def create_translations
    begin
      resource_upload = ResourceUpload.find(params[:resource_upload_id].to_i)
      contents = resource_upload.get_contents
      contents = contents.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: '')
      raise if contents.nil?
    rescue
      set_err('Cannot find this resource upload')
      return
    end

    context = resource_upload.orig_filename

    resource_format = resource_upload.resource_upload_format.resource_format

    create_po = params[:create_po].to_i == 1
    include_affiliate = params[:include_affiliate].to_i == 1

    if params[:include_affiliate].to_i != resource_upload.resource_upload_format.include_affiliate
      resource_upload.resource_upload_format.update_attributes(include_affiliate: params[:include_affiliate].to_i)
    end



    if resource_upload.filename.split('.')[-2] == 'rtf'
      contents.gsub!(/\\$/, "\n")
    end

    # check for the credit link
    if include_affiliate && resource_format.name.index('iPhone')
      contents += "\n\n"
      unless contents .index('ICL_translation_credit')
        contents += "/* ICanLocalize credit footer */\n\"ICL_translation_credit\" = \"Translated by ICanLocalize\";\n"
      end
      unless contents .index('ICL_affiliate_URL')
        contents += "/* ICanLocalize affiliate link */\n\"ICL_affiliate_URL\" = \"http://www.icanlocalize.com/my/invite/%d\";\n" % @text_resource.client.id
      end
    end

    # lines = contents.split(/\r\n|\n|\r/) # NOT USED HERE

    # get the translations and the original strings
    contexts = (@text_resource.extra_contexts || {}).keys.push(context)

    text_resource_string_translations =
      @text_resource.string_translations.
      where('(resource_strings.context IS NULL) OR (resource_strings.context IN (?))', contexts).
      includes(:resource_string)

    if create_po
      # for generating .po files, the string translations dictionary is created from the original string to the translation
      string_translations = {}
      text_resource_string_translations.each do |string_translation|
        next if string_translation.txt.blank?
        resource_string = string_translation.resource_string
        string_translations[resource_string.txt] ||= {}
        string_translations[resource_string.txt][string_translation.language.id] = string_translation.txt
        resource_string.duplicates.each do |duplicate|
          string_translations[duplicate.txt] ||= {}
          string_translations[duplicate.txt][string_translation.language.id] = string_translation.txt
        end
      end

      translated_resources = generate_standalone_pos(string_translations, @text_resource.languages)
    else
      # Todo move this out of the controller.
      # for translating with the original format, the string translations dictionary is created from the token to the translation
      string_translations = {}
      masters_ids = []
      text_resource_string_translations.each do |string_translation|
        if !string_translation.txt.nil?
          resource_string = string_translation.resource_string
          string_translations[[resource_string.token, string_translation.language_id]] = string_translation.txt
          resource_string.duplicates.each do |duplicate|
            if contexts.include?(duplicate.context)
              string_translations[[duplicate.token, string_translation.language_id]] = string_translation.txt
            end
          end
        elsif string_translation.resource_string.master_string
          unless masters_ids.include?(string_translation.resource_string.master_string_id)
            masters_ids << string_translation.resource_string.master_string_id
          end
        end
      end

      # now, we fetch all the masters of all duplicates, regardless of context and fill in the translations only for the current context
      unless masters_ids.empty?
        master_resource_string_translations = @text_resource.string_translations.joins(:resource_string).where('resource_strings.id in (?)', masters_ids)

        master_resource_string_translations.each do |string_translation|
          next if string_translation.txt.blank?
          string_translation.resource_string.duplicates.each do |duplicate|
            if duplicate.context.nil? || (duplicate.context == context)
              string_translations[[duplicate.token, string_translation.language_id]] = string_translation.txt
            end
          end
        end
      end
      begin
        translated_resources = resource_format.merge(contents, string_translations, @text_resource.languages)
      rescue => e
        logger.error e.inspect
        logger.error e.backtrace.join("\n")
        flash[:notice] = e.message
        redirect_back(fallback_location: :index)
        return nil
      end
    end

    # --- save the output files ---

    if File.exist?(resource_upload.all_translations_fname)
      File.delete(resource_upload.all_translations_fname)
    end

    zipfile = Zip::ZipFile.open(resource_upload.all_translations_fname, Zip::ZipFile::CREATE)

    translated_resources.each do |language, translation_and_stats|
      translated_resource = translation_and_stats[0]
      stats = translation_and_stats[1]

      ## TODO: Why there is no java resource format constant
      encoded_resource = if [RESOURCE_FORMAT_XML1, RESOURCE_FORMAT_XML2, RESOURCE_FORMAT_ANDROID].include?(resource_format.kind) || resource_format.name == 'Java'
                           translated_resource
                         else
                           encode_string(translated_resource, resource_format.encoding, @text_resource.bom_enabled?)
                         end

      resource_language = @text_resource.resource_languages.find_by(language_id: language.id)
      orig_filename = resource_upload.orig_filename
      ext_idx = orig_filename.split('.').first.size
      if ext_idx && (ext_idx > 0)
        name = orig_filename[0...ext_idx]
        ext = orig_filename[ext_idx..-1]
      else
        name = orig_filename
        ext = ''
      end
      fname_zip = resource_language.get_output_name.gsub('*', name) + ext
      fname = fname_zip + '.gz'

      upload_translation = resource_upload.upload_translations.find_by(language_id: language.id)
      if upload_translation
        resource_download = upload_translation.resource_download

        if resource_download.filename != fname
          resource_download.filename = fname
          resource_download.save!
        end

        resource_download.set_contents(encoded_resource)
        resource_download.chgtime = Time.now
        resource_download.save!
      else
        # create the file to download
        resource_download = ResourceDownload.new(chgtime: Time.now,
                                                 description: "Translation of resource upload #{resource_upload.id} to #{language.name}",
                                                 filename: fname,
                                                 size: 1,
                                                 content_type: 'application/octet-stream')
        resource_download.text_resource = @text_resource
        resource_download.save!

        resource_download.set_contents(encoded_resource)
        resource_download.save!

        # associate this resource download with the language and the upload
        upload_translation = UploadTranslation.new
        upload_translation.resource_download = resource_download
        upload_translation.resource_upload = resource_upload
        upload_translation.language = language
        upload_translation.save!
      end

      # add to the ZIP file
      zipfile.get_output_stream(fname_zip) { |f| f.write(encoded_resource) }

      # create the stats for this download
      imported_strings = @text_resource.resource_strings.where(context: context).count
      if resource_download.resource_download_stat
        resource_download.resource_download_stat.update_attributes!(total: stats[0], completed: stats[1], imported: imported_strings)
      else
        resource_download_stat = ResourceDownloadStat.new(total: stats[0], completed: stats[1], imported: imported_strings)
        resource_download_stat.resource_download = resource_download
        resource_download_stat.save!
      end

      # Create the corresponding .mo file for PO uploads
      next unless %w(PO Django).include?(resource_format.name)
      temp_fname = File.dirname(resource_download.full_filename) + '/' + resource_download.orig_filename
      tempf = File.new(temp_fname, 'wb')
      tempf.write(resource_download.get_contents)
      tempf.close

      fname_idx = resource_download.orig_filename.split('.').first.size

      mo_basename = resource_download.orig_filename[0...fname_idx] + '.mo'
      mo_fname = File.dirname(resource_download.full_filename) + '/' + mo_basename

      translation = nil
      begin
        translation = GetPomo::PoFile.parse(File.read(temp_fname))
      rescue => e
        logger.error e.inspect
        logger.error e.backtrace.join("\n")
        flash[:notice] = 'Unable to parse file. Django PO files are no ' \
                         'longer supported. If this is not a Django PO ' \
                         'file, please open a support ticket.'
        redirect_back(fallback_location: :index)
        return nil
      end

      translation = translation.each_with_object([]) do |t, memo|
        # icldev-1467 .mo files should not cotain strings that are not translated
        memo << t unless t.msgstr.blank?

        # icldev-1870 Remove escape \ in front of " and '
        %i(msgctxt msgstr msgid).each do |attr|
          t.send(attr).try :gsub!, /(\\)(?="|')/, ''
        end
      end
      translation = nil if translation.empty?

      File.open(mo_fname,'w'){|f|f.print(GetPomo::MoFile.to_text(translation))} unless translation.nil?

      if File.exist?(mo_fname)
        zipfile.get_output_stream(mo_basename) do |f|
          mo_file = File.open(mo_fname, 'rb')
          mo_contents = mo_file.read
          mo_file.close
          f.puts(mo_contents)
        end
      end

      File.delete(temp_fname)
    end

    zipfile.close

    zipfile = File.open(resource_upload.all_translations_fname)
    zipfile.chmod(0666)
    zipfile.close

    flash[:translations] = _('Updated resource files created')
    redirect_to action: :show, anchor: 'resource_upload_%d' % resource_upload.id, page: session[:last_ajax_page]
  end

  def quote_for_resource_translation
    @no_decoded_text_found = false
    @warning = []
    @back = request.referer || '/'
    validate_qoute_params(params)
    @languages = Language.select(:id, :name).order(:name)
    @resource_strings = []
    if @warning.blank? && request.post?
      @resource_format = ResourceFormat.find_by(name: params[:fmt])
      avail_lang = AvailableLanguage.includes(:from_language, :to_language).find_by(from_language_id: params[:lang_from], to_language_id: params[:lang_to])
      if avail_lang.nil?
        @warning << _("We don't have a translator for these languages, please select another pair.")
        return
      end
      cost_per_word = avail_lang.amount.to_f
      @from_language = avail_lang.from_language
      @to_language = avail_lang.to_language

      begin
        resource_upload = params[:resource_upload].read
      rescue
        @warning << _("No file uploaded. If you selected a file and it doesn't work, please use a different type of browser.")
        return
      end

      decoded_src = unencode_string(resource_upload, @resource_format.encoding)

      unless decoded_src
        @warning << _('The uploaded file failed to decode as %s') % RESOURCE_NAME[@resource_format.encoding]
        @no_decoded_text_found = true
        return
      end

      @resource_strings = @resource_format.extract_texts(decoded_src)

      if @resource_strings.empty?
        @warning << _('No texts found')
        @no_decoded_text_found = true
        return
      end

      @word_count = TextResource.word_counter(@resource_strings, @from_language, true)
      @cost = @word_count * cost_per_word * 1.5 # this is part of the free quote, not for clients
      @header = _('Word count for your resource file')
    end
  rescue => e
    flash[:notice] = 'Unable to decode your file, please contact us.'
  end

  def add_from_owner
    if @text_resource.owner.class == WebSupport
      strings_to_add = @text_resource.owner.client_departments.collect { |cd| [cd.class.to_s + cd.id.to_s, cd.name] }
    else
      set_err('cannot handle this owner')
      return
    end

    @updated_strings_count, @existing_strings_count, @added_strings_count, @blocked_strings_count = @text_resource.update_original_strings(strings_to_add, nil)

    flash[:notice] = if @blocked_strings_count > 0
                       _('%d resource strings were added, %d updated and %d ignored. %d strings not updated because they are being translated!') % [@added_strings_count, @updated_strings_count, @existing_strings_count, @blocked_strings_count]
                     else
                       _('%d resource strings were added, %d updated and %d ignored') % [@added_strings_count, @updated_strings_count, @existing_strings_count]
                     end
    redirect_to(action: :show, id: @text_resource.id)
  end

  def return_to_owner
    if @text_resource.owner.class != WebSupport
      set_err('cannot handle this owner')
      return
    end

    resource_strings_cache = {}
    @text_resource.resource_strings.each { |resource_string| resource_strings_cache[resource_string.token] = resource_string }

    @updated_translations = 0

    @text_resource.owner.client_departments.each do |client_department|
      token = client_department.class.to_s + client_department.id.to_s
      resource_string = resource_strings_cache[token]
      next unless resource_string
      # scan all completed translations
      resource_string.string_translations.where(status: STRING_TRANSLATION_COMPLETE).each do |string_translation|
        translation = client_department.db_content_translations.find_by(language_id: string_translation.language_id)
        unless translation
          translation = DbContentTranslation.new
          translation.owner = client_department
          translation.language_id = string_translation.language_id
        end

        next unless translation.txt != string_translation.txt
        translation.txt = string_translation.txt
        translation.save!

        @updated_translations += 1
      end
    end

    flash[:notice] = _('Updated %d translations for support department names.') % @updated_translations
    redirect_to(action: :show, id: @text_resource.id)

  end

  def destroy
    if @text_resource.can_delete?

      # first, credit back all payments for translation work
      user_account = @text_resource.client.find_or_create_account(DEFAULT_CURRENCY_ID)
      @text_resource.resource_languages.each do |resource_language|
        resource_language.money_accounts.each do |money_account|
          next unless money_account.balance > 0
          # transfer the payment to the resource_language account
          money_transaction = MoneyTransactionProcessor.transfer_money(money_account, user_account, money_account.balance, DEFAULT_CURRENCY_ID, TRANSFER_REFUND_FOR_RESOURCE_TRANSLATION)
          if money_transaction
            money_transaction.owner = resource_language
            money_transaction.save!
          else
            flash[:notice] = _('Delete failed')
            redirect_to action: :index
          end
        end
      end

      # has_many :resource_languages, :dependent=>:destroy
      ResourceLanguage.delete(@text_resource.resource_languages.collect(&:id))

      # has_many :resource_uploads, :foreign_key=>:owner_id, :dependent => :destroy
      ResourceUpload.delete(@text_resource.resource_uploads.collect(&:id))

      # has_many :resource_translations, :foreign_key=>:owner_id, :dependent => :destroy
      ResourceTranslation.delete(@text_resource.resource_translations.collect(&:id))

      # has_many :resource_downloads, :foreign_key=>:owner_id, :dependent=>:destroy
      ResourceDownload.delete(@text_resource.resource_downloads.collect(&:id))

      # has_many :resource_chats, :through=>:resource_languages
      ResourceChat.delete(@text_resource.resource_chats.collect(&:id))

      # has_many :resource_strings, :dependent=>:destroy
      # has_many :string_translations, :through=>:resource_strings
      issue_ids = []
      @text_resource.string_translations.each do |st|
        issue_ids += st.issues.collect(&:id)
      end
      Issue.delete(issue_ids)
      StringTranslation.delete(@text_resource.string_translations.collect(&:id))
      ResourceString.delete(@text_resource.resource_strings.collect(&:id))

      # has_many :resource_stats, :dependent=>:destroy
      ResourceStat.delete(@text_resource.resource_stats.collect(&:id))

      TextResource.delete(@text_resource.id)
      flash[:notice] = _('Project deleted')
      redirect_to action: :index
    else
      flash[:notice] = _('The project cannot be deleted right now')
      redirect_to action: :show
    end
  end

  def translation_summary
    @sort = params[:sort] != 0
    @header = _('Translation summary for "%s"') % @text_resource.name
    @simple_cell = !params[:simple_cell].blank?
    @languages = @text_resource.resource_languages.collect(&:language).uniq
  end

  def edit_output_name
    begin
      @resource_language = ResourceLanguage.find(params[:resource_language_id].to_i)
    rescue
      set_err('cannot find resource language')
      return
    end
    if @resource_language.text_resource != @text_resource
      set_err('resource language does not belong to project')
      return
    end

    req = params[:req]

    if req == 'show'
      @editing_output_filename = true
    elsif req.nil?
      @resource_language.update_attributes!(output_name: params[:output_name])
    end
  end

  def browse
    if @text_resource.is_public != 1
      set_err('this is not a public project')
      return
    end

    theme = params[:theme]

    if theme.blank?
      set_err('You must speficy a theme')
      return
    end

    theme_filter = theme + '%'

    @resource_upload =
      @text_resource.resource_uploads.
      includes(:upload_translations)
    where('(zipped_files.filename LIKE ?) AND (zipped_files.by_user_id=?) AND (upload_translations.id IS NOT NULL)', theme_filter, @text_resource.client.id).
      order('zipped_files.id DESC').
      first

    @header = _('Translation files for %s' % theme)
    @look_for_mo = @resource_upload && (@resource_upload.resource_upload_format.resource_format.name == 'PO')

    respond_to do |format|
      format.html
      format.xml
    end
  end

  def edit_media
    req = params[:req]
    @editing_media = true if req == 'show'
  end

  def update_language_status
    begin
      resource_language = @text_resource.resource_languages.find(params[:resource_language_id].to_i)
    rescue
      set_err('could not find this language')
      return
    end

    resource_language.update_attributes(status: params[:status].to_i)
    flash[:notice] = _('Language status updated')
    respond_to do |f|
      f.html { redirect_to action: :show }
      f.js
    end
  end

  def delete_untranslated
    string_ids_to_delete = []
    translations_to_delete = []
    resource_strings = @text_resource.resource_strings.includes(:string_translations).each do |resource_string|
      no_translation = true
      resource_string.string_translations.each do |string_translation|
        if !string_translation.txt.blank? || (string_translation.status != STRING_TRANSLATION_MISSING)
          no_translation = false
          break
        end
      end
      if no_translation
        string_ids_to_delete << resource_string.id
        resource_string.string_translations.each { |st| translations_to_delete << st.id }
      end
    end

    if !string_ids_to_delete.empty?
      ResourceString.where(id: string_ids_to_delete).delete_all
      StringTranslation.where(id: translations_to_delete).delete_all
      flash[:notice] = _('Deleted %d items without translation') % string_ids_to_delete.length
    else
      flash[:notice] = _('No untranslated strings to delete')
    end

    @text_resource.version_num += 1
    @text_resource.save

    redirect_to action: :show

  end

  def find_in_other_projects
    @case_sensitive = params[:case_sensitive].to_i == 1
    other_project_ids = @text_resource.client.text_resources.where('text_resources.id != ?', @text_resource.id).collect(&:id)
    if other_project_ids.empty?
      flash[:notice] = 'This is your only project'
      redirect_to action: :index
      return
    end

    @header = _('Translations from other projects')

    other_resource_strings = {}
    ResourceString.where('(resource_strings.master_string_id IS NULL) AND (resource_strings.text_resource_id IN (?))', other_project_ids).each do |resource_string|
      other_string = @case_sensitive ? resource_string.txt : resource_string.txt.downcase
      other_string.strip!
      other_resource_strings[other_string] = [] unless other_resource_strings.key?(resource_string.txt)
      other_resource_strings[other_string] << resource_string
    end

    @candidates = {}
    @languages = []
    @text_resource.resource_strings.
      joins(:string_translations).
      where('(resource_strings.master_string_id IS NULL) AND (string_translations.status = ?)',
            STRING_TRANSLATION_MISSING).each do |resource_string|

      this_string = @case_sensitive ? resource_string.txt : resource_string.txt.downcase
      this_string.strip!
      next unless other_resource_strings.key?(this_string)
      check_string_ids = other_resource_strings[this_string].collect(&:id)
      resource_translations = {}
      StringTranslation.where('(resource_string_id IN (?)) AND (status = ?)', check_string_ids, STRING_TRANSLATION_COMPLETE).each do |string_translation|
        resource_translations[string_translation.language] = string_translation
      end
      resource_string.string_translations.each do |string_translation|
        next unless resource_translations.key?(string_translation.language)
        @candidates[resource_string] = {} unless @candidates.key?(resource_string)
        @candidates[resource_string][string_translation.language] = resource_translations[string_translation.language]
        @languages << string_translation.language unless @languages.include?(string_translation.language)
      end
    end

    @languages.sort

  end

  def apply_from_other_projects
    count = 0
    max_idx = params[:max_idx].to_i
    (1..max_idx).each do |idx|
      map = params["str_#{idx}"]
      next if map.blank?
      parts = map.split('_')
      next unless parts.length == 2
      next unless params["change_#{map}"].to_i == 1
      translation = params["xlat_#{map}"]
      resource_string_id = parts[0].to_i
      language_id = parts[1].to_i
      string_translation = StringTranslation.where('(resource_string_id=?) AND (language_id=?)', resource_string_id, language_id).first
      if (string_translation.status == STRING_TRANSLATION_MISSING) && (string_translation.resource_string.text_resource_id == @text_resource.id)
        string_translation.update_attributes(status: STRING_TRANSLATION_COMPLETE, review_status: REVIEW_COMPLETED, txt: translation)
        count += 1
      end
    end

    @text_resource.update_version_num

    flash[:notice] = 'Updated %d translations' % count
    redirect_to action: :show
  end

  def edit_tm_use
    req = params[:req]
    if req == 'show'
      @editing = true
    elsif req.nil?
      @text_resource.tm_use_mode = params[:tm_use_mode].to_i
      @text_resource.tm_use_threshold = params[:tm_use_threshold].to_i
      @text_resource.save!
    end
  end

  def edit_resource_account
    unless @user.has_supporter_privileges?
      set_err('You cannot do this operation')
      return
    end

    req = params[:req]
    begin
      resource_account = ResourceLanguageAccount.find(params[:resource_account_id].to_i)
    rescue
      set_err('Cannot find this account')
      return
    end

    if resource_account.resource_language.text_resource != @text_resource
      set_err('Account does not belog to project')
      return
    end

    if req == 'show'
      @editing_resource_account = true
    elsif req.nil?
      balance = params[:balance].to_f
      resource_account.update_attributes!(balance: balance)
    end
    @resource_account = resource_account
  end

  def reset_string_contexts
    unless @text_resource.purge_step.nil?
      set_err('The project is not in the right purge step.')
      return
    end

    ResourceString.transaction do
      @text_resource.resource_strings.joins(:string_translations).where('(string_translations.status != ?) AND (context IS NOT NULL)', STRING_TRANSLATION_BEING_TRANSLATED).each do |resource_string|
        resource_string.update_attributes(context: nil)
      end
      @text_resource.update_attributes(purge_step: TEXT_RESOURCE_PURGE_CHOOSE_FILES)
    end

    flash[:notice] = 'Cleared contexts of all strings. Next, go to the resource files you want to keep strings for and click on "Keep strings in this file".'
    redirect_to action: :show
  end

  def abort_purge_strings
    @text_resource.update_attributes(purge_step: nil)

    flash[:notice] = 'String purge aborted'
    redirect_to action: :show
  end

  def delete_strings_with_no_context
    if @text_resource.purge_step != TEXT_RESOURCE_PURGE_FILES_CHOSEN
      set_err('The project is not in the right purge step.')
      return
    end

    purge_count = 0
    resource_ids = []
    string_translation_ids = []
    @text_resource.resource_strings.joins(:string_translations).where('(context IS NULL) AND  (string_translations.status != ?)', STRING_TRANSLATION_BEING_TRANSLATED).each do |resource_string|
      resource_ids << resource_string.id
      resource_string.string_translations.each { |st| string_translation_ids << st.id }
      purge_count += 1
    end

    ResourceString.where(id: resource_ids).delete_all
    StringTranslation.where(id: string_translation_ids).delete_all

    @text_resource.update_attributes(purge_step: nil, version_num: @text_resource.version_num + 1)

    flash[:notice] = 'Deleted %d strings' % purge_count
    redirect_to action: :show
  end

  def export_csv
    languages = @text_resource.resource_languages.collect(&:language)
    csv_txt = (%w(Label ID context master_string_id language status comment).collect { |f| "\"#{f}\"" }).join(',') + "\r\n"

    @text_resource.resource_strings.includes(:string_translations).each do |resource_string|

      label = resource_string.token
      id = resource_string.id.to_s
      context = (resource_string.context || '')
      master_string_id = (resource_string.master_string_id || 0).to_s
      comment = (resource_string.comment || '')
      translations = {}
      resource_string.string_translations.each { |st| translations[st.language] = st }

      languages.each do |language|
        next unless translations.key?(language)
        st = translations[language]
        text = st.txt
        language = language.name
        id = st.id.to_s
        status = st.status.to_s
        csv_txt += "\"#{label}\",\"#{id}\",\"#{context}\",\"#{master_string_id}\",\"#{language}\",\"#{status}\",\"#{comment}\",\"#{master_string_id}\",\"#{text}\"\n\r"
      end

    end

    send_data(csv_txt,
              filename: 'software_localization_%s_export.csv' % @text_resource.name,
              type: 'text/plain',
              disposition: 'downloaded')

  end

  def export_xml
    languages = @text_resource.resource_languages.collect(&:language)

    xml = REXML::Document.new
    xml.context[:attribute_quote] = :quote

    strings_xml = REXML::Element.new('strings', xml)
    @text_resource.resource_strings.includes(:string_translations).each do |resource_string|

      string_xml = REXML::Element.new('string', strings_xml)
      string_xml.add_attributes('label' => resource_string.token,
                                'id' => resource_string.id.to_s,
                                'context' => (resource_string.context || ''),
                                'master_string_id' => (resource_string.master_string_id || 0).to_s,
                                'comment' => (resource_string.comment || ''))
      string_xml.text = resource_string.txt

      translations = {}
      resource_string.string_translations.each { |st| translations[st.language] = st }

      languages.each do |language|
        next unless translations.key?(language)
        st = translations[language]
        string_translation_xml = REXML::Element.new('translation', string_xml)
        string_translation_xml.add_attributes('language' => language.name, 'id' => st.id.to_s, 'status' => st.status.to_s)
        string_translation_xml.text = st.txt
      end

    end

    formatter = REXML::Formatters::Default.new
    t = ''
    formatter.write(xml, t)
    t = '<?xml version="1.0" encoding="UTF-8"?>' + "\n" + t

    send_data(t,
              filename: 'software_localization_%s_export.xml' % @text_resource.name,
              type: 'text/plain',
              disposition: 'downloaded')

  end

  def import_xml
    content = params[:file].read
    doc = REXML::Document.new(content)

    language_cache = {}
    ids_map = {}

    added = 0

    language_ids = @text_resource.resource_languages.collect(&:language_id)

    ResourceString.transaction do
      doc.elements.each do |strings|
        strings.elements.each do |string|
          txt = string.text
          token = string.attributes['label']
          orig_id = string.attributes['id'].to_i
          orig_master_string_id = string.attributes['master_string_id'].to_i
          context = string.attributes['context']
          comment = string.attributes['comment']

          orig_master_string_id = nil if orig_master_string_id == 0
          context = nil if context.blank?
          comment = nil if comment.blank?

          if orig_master_string_id != 0
            master_string_id = ids_map[orig_master_string_id]
          end

          next unless !token.blank? && !txt.blank? && (orig_id > 0)
          resource_string = ResourceString.new(token: token, context: context, txt: txt, master_string_id: master_string_id, comment: comment)
          resource_string.text_resource = @text_resource
          resource_string.save!

          ids_map[orig_id] = resource_string.id

          added += 1

          added_language_ids = {}

          string.elements.each do |translation|
            txt = translation.text
            language_name = translation.attributes['language']

            unless language_cache.key?(language_name)
              language_cache[language_name] = Language.find_by(name: language_name)
            end

            status = translation.attributes['status'].to_i

            language = language_cache[language_name]
            next unless language
            string_translation = StringTranslation.new(txt: txt, status: status, language_id: language.id)
            string_translation.resource_string = resource_string
            string_translation.save!
            added_language_ids[language.id] = true
          end

          # add blank translations for languages that are in the project but not imported
          language_ids.each do |lid|
            next if added_language_ids.key?(lid)
            string_translation = StringTranslation.new(txt: nil, status: STRING_TRANSLATION_MISSING, language_id: lid)
            string_translation.resource_string = resource_string
            string_translation.save!
          end

        end
      end
    end

    @text_resource.version_num += 1
    @text_resource.save

    flash[:notice] = 'Created %d strings in the project' % added
    redirect_to action: :show

  end

  def cleanup_master_strings
    cleaned = 0
    resource_strings = {}
    @text_resource.resource_strings.each do |rs|
      resource_strings[rs.id] = rs
    end

    resource_strings.each do |_k, v|
      next unless v.master_string_id
      ok = true
      if !resource_strings.key?(v.master_string_id)
        ok = false
      else
        ok = false if resource_strings[v.master_string_id].txt != v.txt
      end

      unless ok
        v.update_attributes(master_string_id: nil)
        cleaned += 1
      end
    end

    flash[:notice] = 'Cleaned %s strings with deleted parents' % cleaned
    redirect_to action: :show

  end

  def change_bom
    @text_resource.update_attribute(:add_bom, !@text_resource.add_bom)
    respond_to do |format|
      format.js
    end
  end

  def update_word_counts
    @text_resource.resource_languages.each(&:update_word_count)

    flash[:notice] = 'Word count has been updated for all languages'
    redirect_to action: :show
  end

  def create_testimonial
    @text_resource.create_testimonial(params)
    flash[:notice] = 'Testimonial has been sent'
    redirect_to :back
  rescue => e
    flash[:notice] = e.message
    redirect_to :back
  end

  private

  def locate_resource
    begin
      @text_resource = TextResource.find(params[:id].to_i)
    rescue ActiveRecord::RecordNotFound
      set_err('Cannot locate this project')
      return false
    end

    if @user && (@user.has_supporter_privileges? || (@text_resource.client == @user))
      return
    end

    @edit_languages = @text_resource.translator_edit_languages(@user) if @user

  end

  def verify_client
    unless @text_resource ? @user.can_view?(@text_resource) : @user.can_create_projects?
      set_err('You cannot access this page')
      false
    end
  end

  def verify_modify
    unless @user.can_modify?(@text_resource)
      set_err("You can't create/update the translations")
      false
    end
  end


  def validate_qoute_params(params)
    unless request.get?
      prompts = {
        resource_upload: 'No file is uploaded',
        fmt: 'Format is blank',
        lang_from: '"From language" is blank',
        lang_to: '"To language" is blank'
      }
      %w(resource_upload fmt lang_from lang_to).each do |field|
        @warning << prompts[field.to_sym] if params[field.to_sym].blank? || (params[field.to_sym] == '0')
      end
    end
  end


end
