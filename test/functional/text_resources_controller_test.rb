require File.dirname(__FILE__) + '/../test_helper'

class TextResourcesControllerTest < ActionController::TestCase
  def test_instant_quote
    post(:quote_for_resource_translation, nil, nil)
    assert assigns(:warning)

    # lang_to only
    post(:quote_for_resource_translation, nil,
         lang_to: 1, ftm: :iPhone)
    assert assigns(:warning)

    # lang_from only
    post(:quote_for_resource_translation, nil,
         lang_from: 1, ftm: :iPhone)
    assert assigns(:warning)

    # no lang
    post(:quote_for_resource_translation, nil,
         resorce_upload: 'file.txt', ftm: :iPhone)
    assert assigns(:warning)

    # lang_to missing
    post(:quote_for_resource_translation, nil,
         lang_from: 1, resorce_upload: 'file.txt', ftm: :iPhone)
    assert assigns(:warning)

    # lang_from missing
    post(:quote_for_resource_translation, nil,
         lang_to: 1, resorce_upload: 'file.txt', ftm: :iPhone)
    assert assigns(:warning)

    # Full
    post(:quote_for_resource_translation, nil,
         lang_to: 1, lang_from: 1, resorce_upload: 'file.txt',  ftm: :iPhone)
    assert :success

    # Full UTF-8
    post(:quote_for_resource_translation, nil,
         lang_to: 1, lang_from: 1, resorce_upload: 'file.txt',  ftm: 'iPhone UTF-8')
    assert :success
  end
end
