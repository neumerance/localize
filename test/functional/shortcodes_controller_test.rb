require File.dirname(__FILE__) + '/../test_helper'
require 'shortcodes_controller'

class ShortcodesControllerTest < ActionController::TestCase
  fixtures :shortcodes, :users, :user_sessions

  # context when logged as a client
  # it should not load shortcodex index without website
  # should be able to add a shortcode for a website that it belongs
  # should not be able to add a shortcode for another website
  # should not be able to add global shortcodes

  test 'should get index' do
    get :index, params: params_with_session(:admin)
    assert_response :success
    assert_not_nil assigns(:shortcodes)
  end

  test 'should get new' do
    get :new, params: params_with_session(:admin)
    assert_response :success
  end

  test 'should create shortcode' do
    assert_difference('Shortcode.count') do
      shortcode_params = { shortcode: 'new-shortcode', comment: 'nothing', content_type: 'atomic' }
      post :create, params: params_with_session(:admin, shortcode: shortcode_params)
    end

    assert_redirected_to shortcodes_path
  end

  test 'should get edit' do
    get :edit, params: params_with_session(:admin, id: shortcodes(:atomic).to_param)
    assert_response :success
  end

  test 'should update shortcode' do
    put :update, params: params_with_session(:admin, id: shortcodes(:atomic).to_param, shortcode: {})
    assert_redirected_to shortcodes_path
  end

  test 'should destroy shortcode' do
    assert_difference('Shortcode.count', -1) do
      delete :destroy, params: params_with_session(:admin, id: shortcodes(:atomic).to_param)
    end

    assert_redirected_to shortcodes_path
  end
end
