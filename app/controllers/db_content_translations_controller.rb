class DbContentTranslationsController < ApplicationController
  prepend_before_action :setup_user

  def edit
    # locate the item
    obj_class = params[:obj_class]
    obj_id = params[:obj_id].to_i
    @language_id = params[:language_id].to_i
    @idx = params[:edit_box].to_i
    req = params[:req]

    ok = false

    if (@idx > 0) && (@language_id > 0) && (obj_class == 'Bionote') || (obj_class == 'Resume')
      begin
        @obj = Document.find(obj_id)
      rescue
      end
    end

    if @obj && (@obj.owner = @user)
      translation = @obj.db_content_translations.where('db_content_translations.language_id=?', @language_id).first
      if req == 'show'
        @txt = translation.txt if translation
        @show_obj = true
      elsif req == 'save'
        if translation
          translation.update_attributes(txt: params[:txt])
        else
          translation = DbContentTranslation.new(txt: params[:txt], language_id: @language_id)
          translation.owner = @obj
          translation.save
        end
      end
      ok = true
    end

    @response = ok
  end

end
