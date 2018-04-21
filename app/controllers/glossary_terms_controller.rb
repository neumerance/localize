require 'csv'
require 'rexml/document'

class GlossaryTermsController < ApplicationController
  include ::Glossary
  include CharConversion

  prepend_before_action :setup_user
  before_action :locate_user
  before_action :locate_term, except: [:index, :new, :create, :new_import, :import, :show_glossary, :csv_export, :ta_glossary_edit, :new_tmx_import, :tmx_import]
  layout :determine_layout

  def index
    @header = _('Glossary terms for %s') % @glossary_client.full_name
    @dont_show_panel = true

    if @user == @glossary_client
      # find the default language
      glossary_terms = @glossary_client.glossary_terms.includes(:glossary_translations)
      orig_language = nil
      languages = []
      glossary_terms.each do |glossary_term|
        orig_language = glossary_term.language unless orig_language
        glossary_term.glossary_translations.each do |glossary_translation|
          unless languages.include?(glossary_translation.language)
            languages << glossary_translation.language
          end
        end
      end
      set_glossary_edit(@user, orig_language, languages) if orig_language
    else
      @show_glossary = true
      session[:show_glossary] = @show_glossary
    end

    respond_to do |format|
      format.html
      format.xml
    end
  end

  def ta_glossary_edit
    from_lang = Language.where('name=?', params[:from_lang]).first
    unless from_lang
      set_err('Cannot set from_lang')
      return
    end

    idx = 1
    cont = true
    to_langs = []
    while cont
      lang_arg = "to_lang#{idx}"
      if !params[lang_arg].blank?

        to_lang = Language.where('name=?', params[lang_arg]).first
        unless to_lang
          set_err('Cannot set %s' % lang_arg)
          return
        end
        to_langs << to_lang
        idx += 1
      else
        cont = false
      end
    end

    if to_langs.empty?
      set_err('No destination languages specified')
      return
    end

    session[:ta_glossary_edit] = true

    set_glossary_edit(@glossary_client, from_lang, to_langs)

  end

  def csv_export
    begin
      export_language = Language.find(params[:language_id].to_i)
    rescue
      flash[:notice] = _('Language not specified')
      redirect_to(action: :index)
      return
    end

    glossary_terms = @glossary_client.glossary_terms.order('glossary_terms.id ASC').includes(:glossary_translations).where('glossary_terms.language_id=?', export_language.id)

    if glossary_terms.empty?
      flash[:notice] = _('No glossary terms from %s') % export_language.name
      redirect_to(action: :index)
      return
    end

    languages = []
    table_rows = []
    glossary_terms.each do |glossary_term|
      cols = {}
      glossary_term.glossary_translations.each do |glossary_translation|
        unless languages.include?(glossary_translation.language)
          languages << glossary_translation.language
        end
        cols[glossary_translation.language] = glossary_translation.txt
      end
      table_rows << [glossary_term, cols]
    end

    languages = languages.sort

    res = [%w(Term Description) + languages.collect(&:name)]
    table_rows.each do |table_row|
      row = []
      row << table_row[0].txt
      row << table_row[0].description
      languages.each do |language|
        row << table_row[1][language]
      end
      res << row
    end

    csv_txt = (res.collect { |row| (row.collect { |cell| "\"#{cell}\"" }).join(',') }).join("\n")

    send_data(csv_txt,
              filename: "#{@glossary_client.full_name} #{export_language.name} glossary.csv",
              type: 'text/plain',
              disposition: 'downloaded')
  end

  def new
    if params[:req].nil?
      @header = _('Create a new glossary term')
      @glossary_term = GlossaryTerm.new
      @glossary_term.language = @glossary_orig_language

      @languages = Language.list_major_first
      @action = :create
      @method = 'POST'
    end
  end

  def edit
    @header = _('Edit a glossary term')
    @languages = Language.list_major_first
    @action = :update
    @method = 'PUT'
  end

  def create
    @warning = nil
    glossary_term = GlossaryTerm.new(params[:glossary_term])
    if glossary_term.valid?
      glossary_term.client = @glossary_client
      ok = glossary_term.save

      @show_glossary = (session[:show_glossary] || false)

      @response = ok
    else
      @warning = list_errors(glossary_term.errors.full_messages, false)
    end
  end

  def update
    @warning = nil
    @glossary_term.assign_attributes(params[:glossary_term])
    if @glossary_term.valid?
      @response = @glossary_term.save!
      @show_glossary = (session[:show_glossary] || false)
      @glossary_term = nil if @response
    else
      @warning = list_errors(@glossary_term.errors.full_messages, false)
    end
  end

  def show
    @header = _('Glossary term details')
    respond_to do |format|
      format.html
      format.xml
    end
  end

  def show_glossary
    @show_glossary = !(session[:show_glossary] || false)
    session[:show_glossary] = @show_glossary
  end

  def new_import
    @header = _('Import new glossary terms from CSV file')
    @languages = Language.list_major_first
    @dont_show_panel = true
  end

  def import
    @dont_show_panel = true
    begin
      @orig_language = Language.find(params[:language_id].to_i)
    rescue
      flash[:notice] = _('Language not selected')
      redirect_to action: :new_import
      return
    end

    @header = _('Import results')

    begin
      txt = params[:file].read
    rescue
      flash[:notice] = _('No file uploaded')
      redirect_to action: :new_import
      return
    end

    txt = convert_to_utf8(txt, source_encoding: CharDet.detect(txt)['encoding'])

    cnt = 0
    @languages = []
    @updated = 0
    @created = 0

    CSV.parse(txt).each do |row|
      if cnt == 0
        if !row || (row.length < 3)
          flash[:notice] = _('Incorrect CSV format')
          redirect_to action: :new_import
          return
        end

        row[2..-1].each do |lang_name|
          language = Language.where('name=?', lang_name).first
          if language
            if @languages.include?(language)
              @problem = _('Language defined twice: %s') % language.name
              return
            else
              @languages << language
            end
          else
            @problem = _('Unknown language: %s') % lang_name
            return
          end
        end
      else
        glossary_term = @glossary_client.glossary_terms.where('(txt=?) AND (description=?) AND (language_id=?)', row[0], row[1], @orig_language.id).first
        if glossary_term
          glossary_term.update_attributes!(description: row[1])
          @updated += 1
        else
          glossary_term = GlossaryTerm.new(txt: row[0], description: row[1])
          glossary_term.language = @orig_language
          glossary_term.client = @glossary_client
          if glossary_term.save
            @created += 1
          else
            @problem = _('Cannot create blank terms')
            return
          end
        end

        # create / update the translations
        idx = 0
        row[2..-1].each do |translation|
          if idx > (@languages.length + 1)
            @problem = _('Too many languages for term %s - %s') % [glossary_term.txt, glossary_term.description]
          end
          unless translation.blank?
            language = @languages[idx]
            glossary_translation = glossary_term.glossary_translations.where('language_id=?', language.id).first
            if glossary_translation
              glossary_translation.update_attributes(txt: translation)
            else
              glossary_translation = GlossaryTranslation.new(txt: translation)
              glossary_translation.language = language
              glossary_translation.glossary_term = glossary_term
              glossary_translation.save
            end
          end
          idx += 1
        end
      end
      cnt += 1
    end

  rescue CSV::MalformedCSVError => e
    flash[:notice] = _('The uploaded CSV file is broken: %s') % e.message
    redirect_to action: :new_import
  rescue => e
    logger.error e.message
    logger.error e.backtrace
    flash[:notice] = _('There was an error processing your file, please contact support and provide your file:')
    redirect_to action: :new_import
  end

  def new_tmx_import
    @header = _('Import new glossary terms from Trados TMX')
    @dont_show_panel = true
  end

  def tmx_import
    @dont_show_panel = true

    @header = _('Import results')

    begin
      txt = params[:file].read
    rescue
      flash[:notice] = _('No file uploaded')
      redirect_to action: :new_tmx_import
      return
    end

    listener = XmlImportTmx.new(logger)
    parser = REXML::Parsers::StreamParser.new(txt, listener)
    parser.parse

    redirect_to action: :new_tmx_import

  end

  def edit_translation
    begin
      @glossary_translation = GlossaryTranslation.find(params[:glossary_translation_id].to_i)
    rescue
    end

    if @glossary_translation
      @language = @glossary_translation.language
      if @glossary_translation.glossary_term != @glossary_term
        set_err('translation does not belong to term')
        return false
      end
    else
      begin
        @language = Language.find(params[:language_id].to_i)
      rescue
        set_err('language not set')
        return
      end
    end

    req = params[:req]

    if req == 'new'
      @glossary_translation = GlossaryTranslation.new
      @glossary_translation.language = @language
      @editing = true
    elsif req == 'show'
      @editing = true
    elsif params[:req].nil?
      if (@user != @glossary_client) && !@glossary_languages.include?(@language)
        set_err('you cannot edit this language')
        return
      end

      if @language == @glossary_term.language
        set_err('cannot add translation to the same language')
        return
      end

      if @glossary_translation
        ok = @glossary_translation.update_attributes(params[:glossary_translation])
      else
        @glossary_translation = GlossaryTranslation.new(params[:glossary_translation])
        @glossary_translation.glossary_term = @glossary_term
        ok = @glossary_translation.save
      end

      @warning = _('The translation cannot be blank') unless ok

    end
  end

  def destroy
    if !params[:confirm_delete].blank?
      @glossary_term.destroy
      @glossary_term = nil
    else
      @warning = 'You must confirm you want to delete the glossary term'
    end
  end

  def locate
    session[:show_glossary] = true
    @show_glossary = true
    @locate = true
  end

  private

  def locate_user
    begin
      @glossary_client = Client.find(params[:user_id].to_i)
    rescue
      set_err('cannot find user')
      return false
    end

    # check that the user can edit
    if @glossary_client == @user
      @glossary_orig_language = session[:glossary_orig_language]
      @glossary_languages = session[:glossary_languages]
      return true
    elsif @user[:type] == 'Translator'
      if (params[:format] == 'xml') || (params[:action] == 'ta_glossary_edit')
        # we leave the full ownership check to the function itself
        return true
      elsif session[:glossary_clients]
        languages_array = session[:glossary_clients][@glossary_client.id]
        if languages_array && !languages_array.empty?
          @glossary_orig_language = languages_array[0]
          @glossary_languages = languages_array[1]

          return true
        end
      end
    end

    set_err('cannot edit this glossary')
    false
  end

  def locate_term
    begin
      @glossary_term = GlossaryTerm.find(params[:id].to_i)
    rescue
      set_err('cannot find term')
      return false
    end

    if @glossary_term.client != @glossary_client
      set_err('term does not belong to user')
      return false
    end

  end

end
