class ResourceTranslationsController < ApplicationController
  prepend_before_action :setup_user
  before_action :locate_parent
  before_action :locate_translation, except: [:create]
  before_action :verify_client
  before_action :setup_help
  layout :determine_layout

  include CharConversion

  STRING_NOT_FOUND = 0
  TRANSLATION_WILL_UPDATE = 1
  TRANSLATION_WILL_REMAIN = 2

  STRING_TRANSLATION_TEXT = { STRING_NOT_FOUND => N_('String not found'),
                              TRANSLATION_WILL_UPDATE => N_('Translation will update'),
                              TRANSLATION_WILL_REMAIN => N_('Translation will stay the same') }.freeze

  STRING_TRANSLATION_COLOR_CODE = { STRING_NOT_FOUND => '#FFE0E0',
                                    TRANSLATION_WILL_UPDATE => '#E0E0FF',
                                    TRANSLATION_WILL_REMAIN => '#FFFFFF' }.freeze
  def show
    @header = _('Uploaded file with existing translations')
  end

  def create

    begin
      @language = Language.find(params[:language_id])
    rescue
      flash[:notice] = _('Please select language')
      redirect_to controller: :text_resources, id: @text_resource.id, action: :new_existing_translation
      return
    end

    if @language == @text_resource.language
      set_err('Cannot be the source language')
      return
    end

    resource_format_id = params[:resource_format_id].to_i
    begin
      @resource_format = ResourceFormat.find(resource_format_id)
    rescue
      set_err('missing resource format')
      return
    end

    begin
      @resource_translation = ResourceTranslation.new(params[:resource_translation])
    rescue
      flash[:notice] = _('Could not process this file. Try uploading with a different browser.')
      redirect_to controller: :text_resources, action: :new_existing_translation, id: @text_resource.id
      return
    end

    @resource_translation.description = "Translation to #{@language.name}"
    @resource_translation.text_resource = @text_resource
    unless @resource_translation.save
      flash[:notice] = _('Could not process this file')
      redirect_to controller: :text_resources, action: :new_existing_translation, id: @text_resource.id
      return
    end

    orig_fname = @resource_translation.full_filename
    @fname = @resource_translation.filename

    @context = params[:context]

    t = Time.now
    decoded_src = unencode_string(@resource_translation.attachment_data, @resource_format.encoding)

    unless decoded_src
      flash[:notice] = _('The uploaded file failed to decode as %s') % RESOURCE_NAME[@resource_format.encoding]
      redirect_to controller: :text_resources, action: :new_existing_translation, id: @text_resource.id
      return
    end

    @resource_translation.set_contents(decoded_src)
    @resource_translation.filename += '.gz'
    @resource_translation.save!
    # File.rename(orig_fname,@resource_translation.full_filename)
    begin
      @resource_strings = @resource_format.extract_texts(decoded_src)
    rescue => e
      logger.error e.inspect
      logger.error e.backtrace.join("\n")
      flash[:notice] = e.message
      redirect_to :back
      return
    end

    # add the status of existing translations
    existing_translations = {}
    @text_resource.string_translations.joins(:resource_string).where('(language_id=?) AND ((resource_strings.context IS NULL) OR (resource_strings.context = ?))', @language.id, @context).each do |string_translation|
      existing_translations[string_translation.resource_string.token] = string_translation
    end

    # add the status of existing translations
    @resource_strings.each do |data|
      token = data[:token]
      has_translation = nil
      status = nil
      current = ''
      if existing_translations.key?(token)
        current = existing_translations[token].txt
        has_translation = data[:translation].gsub(/#{Regexp.escape(PLURAL_SEPARATOR)}/, '').gsub(/\s+/, '') if data[:translation].present?
        status = if has_translation && ((params[:already_translated_strings] == 'update') || [STRING_TRANSLATION_NEEDS_UPDATE, STRING_TRANSLATION_MISSING, STRING_TRANSLATION_BEING_TRANSLATED].include?(existing_translations[token].status))
                   TRANSLATION_WILL_UPDATE
                 else
                   TRANSLATION_WILL_REMAIN
                 end
      else
        status = STRING_NOT_FOUND
      end

      data[:status] = status
      data[:current] = current
    end

    @header = _('Review existing translations')
    @already_translated_strings = params[:already_translated_strings] || 'skip'
  end

  def destroy
    @resource_translation.destroy
    flash[:notice] = _('Translation cancelled')
    redirect_to controller: :text_resources, action: :show, id: @text_resource.id
  end

  def scan_resource
    begin
      @language = Language.find(params[:language_id])
    rescue
      set_err('missing language')
      return
    end

    if @language == @text_resource.language
      set_err('Cannot be the source language')
      return
    end

    resource_format_id = params[:resource_format_id].to_i
    begin
      @resource_format = ResourceFormat.find(resource_format_id)
    rescue
      set_err('missing resource format')
      return
    end

    context = params[:context]

    contents = @resource_translation.get_contents
    strings_to_update = @resource_format.extract_texts(contents)

    # update the translations
    existing_translations = {}
    @text_resource.string_translations.joins(:resource_string).where('(language_id=?) AND ((resource_strings.context IS NULL) OR (resource_strings.context = ?))', @language.id, context).each do |string_translation|
      existing_translations[string_translation.resource_string.token.strip] = string_translation
    end

    updated_strings_count = 0
    # add the status of existing translations
    strings_to_update.each do |data|
      token = data[:token].strip
      value = data[:translation]

      if existing_translations.key?(token) && !value.blank? &&
         (params[:already_translated_strings] == 'update' || [STRING_TRANSLATION_NEEDS_UPDATE, STRING_TRANSLATION_MISSING, STRING_TRANSLATION_BEING_TRANSLATED].include?(existing_translations[token].status))

        string_translation = existing_translations[token]

        # refund if being translated
        if string_translation.status == STRING_TRANSLATION_BEING_TRANSLATED
          string_translation.refund
        end

        # set the string and the status and count it
        string_translation.txt = value
        string_translation.pay_translator = false
        string_translation.status = STRING_TRANSLATION_COMPLETE
        string_translation.save!

        updated_strings_count += 1

        string_translation.add_to_tm
      end
    end

    # indicate that this file is OK
    @resource_translation.normal_user = @user
    @resource_translation.save!

    resource_language = @text_resource.resource_languages.where('language_id=?', @language.id).first
    resource_language.update_version_num

    flash[:notice] = _('Translation of %d strings was updated') % updated_strings_count
    redirect_to(controller: :text_resources, action: :show, id: @text_resource.id)
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

  def locate_translation
    begin
      @resource_translation = ResourceTranslation.find(params[:id].to_i)
    rescue
      set_err('Cannot find this upload')
      return false
    end

    if @resource_translation.text_resource != @text_resource
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

end
