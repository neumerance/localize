require File.dirname(__FILE__) + '/../test_helper'

class TranslationSnapshotsControllerTest < ActionController::TestCase
  def test_create_by_cms
    def create_by_cms(params, code)
      post :create_by_cms, params: { format: 'xml' }.merge(params)
      assert_response :success
      xml = get_xml_tree(@response.body)
      assert_element_attribute(code, xml.root.elements['status'], 'err_code')
    end

    # empty
    params = { date: '2012-01-01' }
    create_by_cms(params, TranslationSnapshotsController::ERR_UNKNOWN_WEBSITE.to_s)

    # Can't find site
    params[:website_id] = 999999999999
    params[:accesskey] = 'd87fdjklh34'
    create_by_cms(params, TranslationSnapshotsController::ERR_UNKNOWN_WEBSITE.to_s)

    # wrong accesskey
    params[:website_id] = 1
    params[:accesskey] = 'd87fdjklh34'
    create_by_cms(params, TranslationSnapshotsController::ERR_UNKNOWN_WEBSITE.to_s)

    # Fixed accesskey
    params[:accesskey] = 'd87fdjklh345'
    create_by_cms(params, TranslationSnapshotsController::ERR_UNKNOWN_LANGUAGES.to_s)

    # unexisting from language
    params[:from_language_name] = 'notexist'
    params[:to_language_name] = 'Spanish'
    create_by_cms(params, TranslationSnapshotsController::ERR_UNKNOWN_LANGUAGES.to_s)

    # unexisting to language
    params[:from_language_name] = 'English'
    params[:to_language_name] = 'donotexistagain'
    create_by_cms(params, TranslationSnapshotsController::ERR_UNKNOWN_LANGUAGES.to_s)

    # from future
    params[:from_language_name] = 'English'
    params[:to_language_name] = 'Spanish'
    params[:date] = '9999-12-30'
    create_by_cms(params, TranslationSnapshotsController::ERR_FROM_FUTURE.to_s)

    # existing language
    params[:date] = '2000-01-01'
    create_by_cms(params, '0')

    # duplicated date
    create_by_cms(params, TranslationSnapshotsController::ERR_DUPLICATE_DATE.to_s)
  end

end
