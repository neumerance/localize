class StringTranslationsController < ApplicationController
  prepend_before_action :setup_user
  before_action :verify_supporter
  before_action :locate_string

  def force_review
    @string_translation.update_attribute :review_status, REVIEW_COMPLETED
    redirect_to :back
  end

  private

  def locate_string
    @string_translation = StringTranslation.find(params[:id])

    unless @string_translation
      set_err("Can't find this string")
      return false
    end
  end
end
