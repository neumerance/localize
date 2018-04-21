require 'rchardet'

class ResourceUploadsController < ApplicationController
  prepend_before_action :setup_user
  before_action :locate_parent
  before_action :locate_upload, except: [:index, :new, :create]
  before_action :verify_client
  before_action :setup_help
  before_action :verify_can_modify, only: [:create]
  layout :determine_layout

  include CharConversion
  include ActionView::Helpers::TagHelper

  NEW_STRING_MISSING = 0
  NEW_STRING_EXISTS = 1
  NEW_STRING_MODIFIED = 2
  NEW_STRING_DUPLICATE = 3
  NEW_STRING_BEING_TRANSLATED = 4

  NEW_STRING_TEXT = { NEW_STRING_MISSING => N_('New string'),
                      NEW_STRING_EXISTS => N_('String exists'),
                      NEW_STRING_MODIFIED => N_('String modified'),
                      NEW_STRING_DUPLICATE => N_('Duplicate string'),
                      NEW_STRING_BEING_TRANSLATED => N_('Translation or review in progress') }.freeze

  NEW_STRING_COLOR_CODE = { NEW_STRING_EXISTS => '#FFFFFF',
                            NEW_STRING_MISSING => '#FFE0E0',
                            NEW_STRING_MODIFIED => '#FFF0A8',
                            NEW_STRING_DUPLICATE => '#FFFFFF',
                            NEW_STRING_BEING_TRANSLATED => '#E0E0FF' }.freeze

  def index
    params[:page] ||= 1
    session[:last_ajax_page] = params[:page]

    @text_resource = TextResource.find params[:text_resource_id]

    @pager = ::Paginator.new(@text_resource.resource_uploads.count, 10) do |offset, per_page|
      @text_resource.resource_uploads.limit(per_page).offset(offset).order('id DESC')
    end

    @resource_uploads = @pager.page(params[:page])
    @list_of_pages = []
    for idx in 1..@pager.number_of_pages
      @list_of_pages << idx
    end
    @show_number_of_pages = true

    respond_to do |format|
      format.js
    end
  end

  def show
    @header = _('Uploaded file')
  end

  def create
    begin
      resource_format = ResourceFormat.find(params[:resource_format_id].to_i)
    rescue
      flash[:problem] = _('cannot find the specified format')
      redirect_to controller: :text_resources, action: :show, id: @text_resource.id, anchor: 'upload_new'
      return
    end

    begin
      @resource_upload = ResourceUpload.new(params[:resource_upload])
    rescue
      flash[:problem] = _('Upload failed. Please try using a different type of browser.')
      redirect_to controller: :text_resources, action: :show, id: @text_resource.id, anchor: 'upload_new'
      return
    end

    @resource_upload.description = resource_format.id.to_s
    @resource_upload.text_resource = @text_resource
    unless @resource_upload.save
      flash[:problem] = _('Could not process this file. Did you choose a file to upload?')
      redirect_to text_resource_path(@text_resource, anchor: 'upload_new')
      return
    end

    # remember the format
    resource_upload_format = ResourceUploadFormat.new
    resource_upload_format.resource_upload = @resource_upload
    resource_upload_format.resource_format = resource_format
    resource_upload_format.save!

    orig_fname = @resource_upload.full_filename

    # If client choosed UTF-8, better check if he is right
    if resource_format.id == 12
      unless %w(utf-8 utf8 UTF-8 UTF8 ascii ASCII).include?(CharDet.detect(@resource_upload.attachment_data)['encoding'])
        logger.debug CharDet.detect(@resource_upload.attachment_data)['encoding']
        @format_error = true
      end
    end

    decoded_src = unencode_string(@resource_upload.attachment_data, resource_format.encoding)
    unless decoded_src
      flash[:problem] = (_('The format of the uploaded file does not appear to be <b>%s</b>.') % RESOURCE_NAME[resource_format.encoding]).html_safe
      redirect_to text_resource_path(@text_resource, anchor: 'upload_new')
      return
    end

    @resource_upload.set_contents(decoded_src)
    @resource_upload.filename += '.gz'
    @resource_upload.save!
    @resource_upload.send_to_s3
    logger.debug orig_fname.inspect
    logger.debug @resource_upload.full_filename.inspect

    # File.rename(orig_fname,@resource_upload.full_filename)
    @resource_strings = []
    begin
      raise Parsers::EmojisNotSupported if include_emoji? decoded_src
      @resource_strings = resource_format.extract_texts(decoded_src)
    rescue Parsers::EmojisNotSupported => e
      flash[:problem] = content_tag(:p, 'The uploaded file contains emojis. Unfortunatelly, they are not supported. Please remove all emojis and try again.')
    rescue Parsers::ParseError => e
      Parsers.logger("Error parsing file Parsers::ParseError ResourceUpload.id = #{@resource_upload.id}", e)

      flash[:problem] = e.message
      flash[:suggestions] = e.suggestions if e.suggestions
    rescue StandardError => e
      Parsers.logger("General Error parsing file ResourceUpload.id = #{@resource_upload.id}", e, true)

      flash[:problem] = 'File not valid. Please contact support to try to identify the problem with your file.'
    end

    if @resource_strings.empty?
      unless flash[:problem]
        flash[:problem] = content_tag(:p, 'We could not find any strings in this resource file.') +
                          content_tag(:p, 'Make sure that the resource file format is for '.html_safe +
                          content_tag(:b, resource_format.name) + " and that it's encoded as ".html_safe +
                          content_tag(:b, RESOURCE_NAME[resource_format.encoding]))
      end

      redirect_to text_resource_path(@text_resource, anchor: 'upload_new')
      return
    end

    context = @resource_upload.orig_filename

    # add the status of existing translations
    existing_strings = {}
    already_added = {}
    being_translated = {}
    review_enabled_languages = {}
    @text_resource.resource_languages.each do |resource_language|
      if resource_language.managed_work && (resource_language.managed_work.active == MANAGED_WORK_ACTIVE) && resource_language.managed_work.translator
        review_enabled_languages[resource_language.language_id] = true
      end
    end

    @text_resource.resource_strings.includes(:string_translations).each do |resource_string|
      if (resource_string.context == context) || resource_string.context.blank?
        existing_strings[resource_string.token] = resource_string.txt

        resource_string.string_translations.each do |string_translation|
          if (string_translation.status == STRING_TRANSLATION_BEING_TRANSLATED) ||
             (review_enabled_languages.key?(string_translation.language_id) &&
              [REVIEW_AFTER_TRANSLATION, REVIEW_PENDING_ALREADY_FUNDED].include?(string_translation.review_status))
            being_translated[resource_string.token] = true
            break
          end
        end
      end
      already_added[resource_string.txt] = true
    end

    ignore_duplicates = params[:ignore_duplicates].to_i

    # add the status of existing translations
    @strings_for_word_count = []
    @modified_strings = []
    @resource_strings.each do |data|
      token = data[:token][0..254] # recognize larger tokens as duplicate too
      # changed applied for https://onthegosystems.myjetbrains.com/youtrack/issue/iclsupp-1656
      if existing_strings.key?(token) && existing_strings[token].strip != data[:text].strip && !being_translated.key?(token)
        @modified_strings << [token, existing_strings[token], data[:text]]
      end

      status = if being_translated.key?(token)
                 NEW_STRING_BEING_TRANSLATED
               else
                 if existing_strings.key?(token)
                   existing_strings[token].strip == data[:text].strip ? NEW_STRING_EXISTS : NEW_STRING_MODIFIED
                 else
                   NEW_STRING_MISSING
                 end
               end

      # check for duplicate strings in this batch
      if (status != NEW_STRING_EXISTS) && (status != NEW_STRING_BEING_TRANSLATED)
        if (ignore_duplicates == 1) && already_added.key?(data[:text])
          status = NEW_STRING_DUPLICATE
        else
          already_added[token] = true
          @strings_for_word_count << data
        end
      end
      data[:status] = status
    end

    # remember the selected format
    @text_resource.resource_format = resource_format
    @text_resource.ignore_duplicates = ignore_duplicates
    @text_resource.save!

    @word_count = @text_resource.count_words(@strings_for_word_count, @text_resource.language, nil, true)

    @header = _('Review uploaded resource file')
  end

  def destroy
    @resource_upload.destroy
    flash[:notice] = _('Uploaded file removed')
    redirect_to controller: :text_resources, action: :show, id: @text_resource.id, anchor: 'uploads'
  end

  # POST
  # It's executed when the user choose the strings to add after upload resource file
  # This is what actually adds the strings
  def scan_resource
    contents = @resource_upload.get_contents
    strings_to_add = @text_resource.resource_format.extract_texts(contents)

    enabled_strings = []
    strings_to_add.each do |entry|
      if params[:string_token] && params[:string_token].include?(Digest::MD5.hexdigest(entry[:token]))
        enabled_strings << entry
      end
    end

    use_translations = params[:updating_text].nil? ? false : true

    # TODO: Refactor update_original_strings and update the comments in only one run
    begin
      @updated_strings_count,
      @existing_strings_count,
      @added_strings_count,
      @blocked_strings_count = @text_resource.update_original_strings(enabled_strings, @resource_upload, use_translations)
    rescue ActiveRecord::StatementInvalid => e
      Parsers.logger("Error saving ResourceStrings for TextResource #{@text_resource.id}, contains characters not valid for DB", e, true)

      flash[:problem] = _('Unfortunately, we were not able to include the chosen strings. It\'s probably that your file contains characters that are not compatible with our current translation platform like emojis, you can remove them and try again. If you need further help, please contact support by opening a ticket.')
      redirect_to text_resource_path(@text_resource, anchor: 'upload_new')
      return
    end

    @text_resource.update_comments(strings_to_add)

    # indicate that this file is OK
    @resource_upload.normal_user = @user.master_account || @user
    @resource_upload.status = 1
    @resource_upload.save!

    flash[:notice] = if @blocked_strings_count > 0
                       _('%d resource strings were added, %d updated and %d ignored. %d strings not updated because they are being translated!') % [@added_strings_count, @updated_strings_count, @existing_strings_count, @blocked_strings_count]
                     else
                       _('%d resource strings were added, %d updated and %d ignored') % [@added_strings_count, @updated_strings_count, @existing_strings_count]
                     end

    redirect_to @text_resource
  end

  def download_translations
    send_file(@resource_upload.all_translations_fname)
  end

  def apply_to_context
    contents = @resource_upload.get_contents
    unless contents
      flash[:notice] = 'File not found.'
      redirect_to controller: :text_resources, action: :show, id: @text_resource.id
      return
    end

    strings_to_add = @text_resource.resource_format.extract_texts(contents)

    context = @resource_upload.orig_filename

    existing_strings = {}
    @text_resource.resource_strings.where('context = ?', context).each { |resource_string| existing_strings[resource_string.token] = resource_string }

    master_strings = {}
    slave_strings = {}
    @text_resource.resource_strings.joins(:string_translations).where('(context IS NULL) AND (string_translations.status != ?)', STRING_TRANSLATION_BEING_TRANSLATED).each do |resource_string|
      if !resource_string.master_string_id
        master_strings[resource_string.token] = resource_string
      else
        slave_strings[resource_string.token] = resource_string
      end
    end

    added_count = 0

    not_found = []

    ResourceString.transaction do
      strings_to_add.each do |s|
        token = s[:token]
        next if existing_strings.key?(token)
        if master_strings.key?(token)
          master_strings[token].update_attributes(context: context)
          added_count += 1
        elsif slave_strings.key?(token)
          slave_strings[token].update_attributes(context: context)
          added_count += 1
        else
          not_found << s
        end
      end
    end

    unless not_found.empty?

      language_ids = @text_resource.resource_languages.collect(&:language_id)

      not_found.each do |s|
        token = s[:token]
        orig_string = @text_resource.resource_strings.includes(:string_translations).where('(context IS NOT NULL) AND (token = ?)', token).first
        next unless orig_string
        ResourceString.transaction do
          resource_string = ResourceString.new(token: token, txt: s[:text], master_string_id: orig_string.id)
          resource_string.text_resource = @text_resource
          resource_string.save

          # add blank translations in all languages
          language_ids.each do |language_id|
            string_translation = StringTranslation.create!(language_id: language_id, txt: nil, resource_string_id: resource_string.id, status: STRING_TRANSLATION_MISSING)
          end
        end
        added_count += 1
      end
    end

    orphan_count = @text_resource.resource_strings.joins(:string_translations).where('(context IS NULL) AND (string_translations.status != ?)', STRING_TRANSLATION_BEING_TRANSLATED).count

    if orphan_count > 0
      @text_resource.update_attributes(purge_step: TEXT_RESOURCE_PURGE_FILES_CHOSEN)
      flash[:notice] = 'Found %d new strings that belong to this resource file.' % added_count
    else
      @text_resource.update_attributes(purge_step: nil)
      flash[:notice] = 'All strings in the project belong to uploaded resource files that you selected. No unused strings to delete.'
    end

    redirect_to controller: :text_resources, action: :show, id: @text_resource.id

  end

  private

  def locate_parent
    begin
      @text_resource = TextResource.find(params[:text_resource_id].to_i)
    rescue
      set_err('Cannot locate this project')
      return false
    end
    if ![@user, @user.master_account].include?(@text_resource.client) && !@user.has_supporter_privileges?
      set_err('Not your project')
      return false
    end
  end

  def locate_upload
    begin
      @resource_upload = ResourceUpload.find(params[:id].to_i)
    rescue
      set_err('Cannot find this upload')
      return false
    end

    if @resource_upload.text_resource != @text_resource
      set_err('This upload does not belong to the project')
      return false
    end
  end

  def verify_client
    if ![@user, @user.master_account].include?(@text_resource.client) && !@user.has_supporter_privileges?
      set_err('You cannot access this page')
      false
    end
  end

  def verify_can_modify
    unless @user.can_modify?(@text_resource)
      set_err('You cannot access this page')
      false
    end
  end

end
